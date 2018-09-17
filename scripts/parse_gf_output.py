from sys import stderr

def eprint(*args, **kwargs):
    print(*args, file=stderr, **kwargs)

def gf_escape(s):
    return s.replace("$", "") \
            .replace("(", "LBR") \
            .replace(")", "RBR") \
            .replace(".", "PUNCT") \
            .replace(",", "COMMA") \
            .replace("--", "MDASH") \
            .replace("-", "DASH") \
            .replace("/", "SLASH") \
            .replace("\\", "BACKSLASH") \
            .replace("\"", "DQ") \
            .replace("'", "SQ")


if __name__ == "__main__":
    import re
    from sys import stdin, argv

    assert len(argv) == 2, "use %s <sentence file>" %argv[0]

    deriv = re.compile(r"""^[^>]+> (\(.*\))$""")
    pos_annot = re.compile(r"""(\([^\d\s]+)\d:\d+""")
    illegalderiv = re.compile(r"""^\([^\s]+ [^\(\)]+\)$""")
    time = re.compile(r"""^(\d+) msec$""")

    sentence = re.compile(r"""^(\d+)\s+(.*)$""")
    
    def illegal_deriv(input_words, deriv):
        words_with_pos = re.compile(r"""\(([^\s]+) ([^\(\)\s]+)\)""")
        wps = words_with_pos.findall(deriv)
        if not wps: return True
        poss, words = zip(*wps)
        return any([pos.startswith("VROOT") for pos in poss]) or tuple(words) != tuple(input_words)
 
    word_pos = re.compile(r"""([^\s]+)/([^\s/]+)""")
    sentences = []
    with open(argv[1]) as sentence_file:
        for line in sentence_file:
            if line.strip():
                _, words = sentence.match(line).group(1, 2)
                sentences.append([(gf_escape(pos), gf_escape(word)) for (pos, word) in  word_pos.findall(words)])

    last_passed = True
    index = 0
    for line in stdin:
        if line.strip() == "grammargfabstract> See you.":
            break
        
        derivm = deriv.match(line)
        timem = time.match(line)
        if derivm:
            sexp = pos_annot.sub(lambda m: m.group(1), derivm.group(1))
            if illegal_deriv([word for (word, _) in sentences[index]], sexp):
                print("(VROOT (NOPARSE %s))" %" ".join(["(%s %s)"%(pos, word) for (word, pos) in sentences[index]]))
                last_passed = False
            else:
                print(sexp)
                last_passed = True
        elif timem:
            eprint( "%d\t%s\t%d" %(len(sentences[index]), timem.group(1), 1 if last_passed else 0) )
            index += 1