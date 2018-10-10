# Adds the sentence id to a given list of trees in export format.

if __name__ == "__main__":
    import re
    from sys import stdin, argv

    assert len(argv) == 2, "use %s <sentence file>"

    sentences = {}
    with open(argv[1]) as sentencefile:
        sentence_id = re.compile(r"""^(\d+)\s+(.*)$""")
        word = re.compile(r"""([^\s]+)/[^/\s]+""")
        for line in sentencefile:
            if line.strip():
                sid, sentence = sentence_id.match(line).group(1, 2)
                words = tuple(word.findall(sentence))
                
                if words in sentences:
                    sentences[words].append(sid)
                else:
                    sentences[words] = [sid]

    corpus_sep_pattern = re.compile(r"#BOS(?:(?!#EOS).+\n)+\#EOS\s\d+")
    words = re.compile(r"""(?:^|\n)([^#\s]+)""")
    trees = corpus_sep_pattern.findall(stdin.read())

    for tree in trees:
        ws = tuple(words.findall(tree))
        sid = int(sentences[ws].pop(0))
        print("#BOS %d" %sid)
        for line in tree.splitlines()[1:-1]:
            print(line)
        print("#EOS %d" %sid)
