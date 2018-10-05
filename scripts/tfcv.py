import re

def ten_folds(indices):
    # iterator over inclusive ranges of indices
    start = 0
    step = int(indices / 10)
    
    for _ in [[]]*9:
        yield (start, start + step - 1)
        start = start + step
    
    yield (start, indices - 1)


def tokens(treestr):
    # yields tokens in a tree
    reg = re.compile("^[^#\s]+", flags = re.MULTILINE)
    for match in reg.finditer(treestr):
        yield match.group(0)


def fix_bos(tree):
    reg = re.compile("^(#BOS \d+)(\s+%%.*)?$")
    treelines = tree.splitlines()

    try:
        (fst, snd) = reg.search(treelines[0]).groups()
        treelines[0] = "{} 0 0 0{}".format(fst, snd if snd else "")
    except:
        pass
    
    return "\n".join(treelines)


def remove_snd_col(tree):
    reg = re.compile("^#BOS \d+$")
    treelines = tree.splitlines()

    reg = re.compile("^([^\s]+\s+)[^\s]+\s+(.*)$")
    for i in range(1, len(treelines) - 1):
        prefix = reg.match(treelines[i])
        if not prefix is None:
            treelines[i] = prefix.group(1) + prefix.group(2)
    
    return "\n".join(treelines)


def get_optional_arguments(dic):
    for key in dic:
        for arg in argv:
            match = re.match("^--%s=(.*)$" %key, arg)
            if match:
                dic[key] = match.group(1)
                break
    return dic

def word_pos(tree, export_format):
    word_pos_pattern_v3 = re.compile(r"(^[^#\s]+)\s+([^#\s]+)", re.MULTILINE)
    word_pos_pattern_v4 = re.compile(r"(^[^#\s]+)\s+[^\s]+\s+([^#\s]+)", re.MULTILINE)

    if export_format == "3":
        return word_pos_pattern_v3.findall(tree)
    elif export_format == "4":
        return word_pos_pattern_v4.findall(tree)
    else:
        raise Exception("export format not supported")
    


if __name__ == "__main__":
    from sys import argv, stderr
    help = """use %s <NEGRA FILE> [OPTIONS]
              where OPTIONS is some combination of
                --max-length=<max tokens of test sentence>
                --out-prefix=<folder to put files into>
                --remove-snd-col=(true|false*)
                --fix-bos=(true|false*)
                --help""" %argv[0]

    assert len(argv) > 1, help
    if "--help" in argv:
        print(help)
        exit(0)

    optional_arguments = get_optional_arguments({ "max-length": None, "out-prefix": "", "fix-bos": None, "remove-snd-col": None })
    
    max_length = int(optional_arguments["max-length"]) if optional_arguments["max-length"] else 1000
    
    prefix = optional_arguments["out-prefix"]
    if prefix and prefix[-1] != '/': prefix = prefix + "/"
    
    fix = optional_arguments["fix-bos"] in ["yes", "true", "True", "on"]
    rm_snd = optional_arguments["remove-snd-col"] in ["yes", "true", "True", "on"]
    def post_proc(tree):
        if fix_bos:
            tree = fix_bos(tree)
        if rm_snd:
            tree = remove_snd_col(tree)
        return tree
    
    corpus_sep_pattern = re.compile(r"#BOS(?:(?!#EOS).+\n)+\#EOS\s\d+")
    id_pattern = re.compile(r"^#BOS (\d+)")
    format_pattern = re.compile(r"#FORMAT (\d)")
    
    with open(argv[1]) as corpus_file:
        file_contents = corpus_file.read()
        try:
            form = format_pattern.search(file_contents).group(1)
        except:
            print("could not find format specification, using v4", file=stderr)
            form = "4"
        trees = corpus_sep_pattern.findall(file_contents)

        sub_corpora = [[trees[index] for index in range(first, last +1)] for (first, last) in ten_folds(len(trees))]

        for (fold, test) in enumerate(sub_corpora):
            train = [post_proc(tree) for (tfold, sub_corpus) in enumerate(sub_corpora) if tfold != fold for tree in sub_corpus]
            test = [post_proc(tree) for tree in test]

            with open("%strain-%d.export" %(prefix, fold), "w") as trainfile:
                trainfile.write("#FORMAT {}\n".format(form) + "\n".join([tree for tree in train]))
            with open("%stest-%d.export" %(prefix, fold), "w") as testfile:
                testfile.write("#FORMAT {}\n".format(form) + "\n".join([testtree for testtree in test if len(list(tokens(testtree))) <= max_length]))
            
            with open("%strain-%d.sent" %(prefix, fold), "w") as trainsents:
                trainsents.write(
                    "\n".join([id_pattern.search(tree).group(1) + "\t" + " ".join(["/".join(wp) for wp in word_pos(tree, form)]) for tree in train])
                )
            with open("%stest-%d.sent" %(prefix, fold), "w") as testsents:
                testsents.write(
                    "\n".join([id_pattern.search(tree).group(1)+ "\t" + " ".join(["/".join(wp) for wp in word_pos(tree, form)]) for tree in test if len(list(tokens(tree))) <= max_length])
                )