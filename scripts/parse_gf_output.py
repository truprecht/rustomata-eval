from sys import stderr

def eprint(*args, **kwargs):
    print(*args, file=stderr, **kwargs)

if __name__ == "__main__":
    import re
    from sys import stdin, argv

    assert len(argv) == 2, "use %s <sentence file>" %argv[0]

    deriv = re.compile(r"""^[^>]+> (\(.*\))$""")
    illegalderiv = re.compile(r"""^\([^\s]+ [^\(\)]+\)$""")
    time = re.compile(r"""^(\d+) msec$""")

    sentence = re.compile(r"""^(\d+)\s+(.*)$""")
    word_pos = re.compile(r"""([^\s]+)/([^\s/]+)""")
    sentences = []
    with open(argv[1]) as sentence_file:
        for line in sentence_file:
            if line.strip():
                sentence_id, words = sentence.match(line).group(1, 2)
                sentences.append(( int(sentence_id), word_pos.findall(words) ))

    last_passed = True
    index = 0
    for line in stdin:
        if line.strip() == "grammargfabstract> See you.":
            break
        
        derivm = deriv.match(line)
        timem = time.match(line)
        if derivm:
            illegalderivm = illegalderiv.match(derivm.group(1))
            if illegalderivm or derivm.group(1) == "(_:0)":
                print("(VROOT (NOPARSE %s))" %" ".join(["(%s %s)"%(pos, word) for (word, pos) in sentences[index][1]]))
                last_passed = False
            else:
                print(derivm.group(1))
                last_passed = True
        elif timem:
            eprint( "%d\t%s\t%d" %(len(sentences[index][1]), timem.group(1), 1 if last_passed else 0) )
            index += 1