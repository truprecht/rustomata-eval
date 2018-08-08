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


def fix_discodop_output(tree):
    # add defaults for export fields removed by discodop
    # removes some additional `--`s that were added by discodop
    reg = re.compile("^#BOS \d+$")
    treelines = tree.splitlines()

    if reg.match(treelines[0]):
        treelines[0] += " 0 0 0"

    reg = re.compile("^([^\s]+\s+)--\s(.*)$")
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

if __name__ == "__main__":
    from sys import argv
    help = """use %s <NEGRA FILE> [OPTIONS]
              where OPTIONS is some combination of
                --max-length=<max tokens of test sentence>
                --out-prefix=<folder to put files into>
                --fix-discodop-transformation=(true|false*)
                --help""" %argv[0]

    assert len(argv) > 1, help
    if "--help" in argv:
        print(help)
        exit(0)

    optional_arguments = get_optional_arguments({ "max-length": None, "out-prefix": "", "fix-discodop-transformation": None })
    max_length, prefix, fix = int(optional_arguments["max-length"]), optional_arguments["out-prefix"], optional_arguments["fix-discodop-transformation"] in ["yes", "true", "True", "on"]
    if prefix and prefix[-1] != '/': prefix = prefix + "/"
    
    corpus_sep_pattern = re.compile(r"#BOS(?:(?!#EOS).+\n)+\#EOS\s\d+")
    word_pos_pattern = re.compile(r"(^[^#\s]+)\s+([^#\s]+)", re.MULTILINE)
    id_pattern = re.compile(r"^#BOS (\d+)")
    
    with open(argv[1]) as corpus_file:
        trees = corpus_sep_pattern.findall(corpus_file.read())

        sub_corpora = [[trees[index] for index in range(first, last +1)] for (first, last) in ten_folds(len(trees))]

        for (fold, test) in enumerate(sub_corpora):
            train = [tree if not fix else fix_discodop_output(tree) for (tfold, sub_corpus) in enumerate(sub_corpora) if tfold != fold for tree in sub_corpus]
            if fix: test = [fix_discodop_output(tree) for tree in test]

            with open("%strain-%d.export" %(prefix, fold), "w") as trainfile:
                trainfile.write("#FORMAT 3\n" + "\n".join([tree for tree in train]))
            with open("%stest-%d.export" %(prefix, fold), "w") as testfile:
                testfile.write("#FORMAT 3\n" + "\n".join([testtree for testtree in test if len(list(tokens(testtree))) <= max_length]))
            
            with open("%strain-%d.sent" %(prefix, fold), "w") as trainsents:
                trainsents.write(
                    "\n".join([id_pattern.search(tree).group(1) + "\t" + " ".join(["/".join(wp) for wp in word_pos_pattern.findall(tree)]) for tree in train])
                )
            with open("%stest-%d.sent" %(prefix, fold), "w") as testsents:
                testsents.write(
                    "\n".join([id_pattern.search(tree).group(1)+ "\t" + " ".join(["/".join(wp) for wp in word_pos_pattern.findall(tree)]) for tree in test if len(list(tokens(tree))) <= max_length])
                )