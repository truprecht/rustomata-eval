# Fills a list of trees in export format with missing sentences. These missing sentences are
# read from a list of all sentences for that should be a tree in the given list.
# E.g. suppose there is a list of parse trees, but somehow the second tree with id "3"
# is missing, then this script prints the list plus a noparse tree for the sentence with id "3".

if __name__ == "__main__":
    import re
    from sys import argv, stdin

    assert len(argv) == 2, "use %s <test sentences> < <predicted parse trees> > <predicted parse trees with noparse>" %argv[0]

    bos = re.compile(r"""^#BOS (\d+)""")
    sentence = re.compile(r"""^(\d+)\s+(.*)$""")
    word_pos = re.compile(r"""([^\s]+)/([^\s/]+)""")
    sentences = {}
    with open(argv[1]) as sentence_file:
        for line in sentence_file:
            if line.strip():
                sentence_id, words = sentence.match(line).group(1, 2)
                sentences[int(sentence_id)] = word_pos.findall(words)
    
    last_prediction = -1
    for line in stdin:
        m = bos.match(line)
        if m:
            target = int(m.group(1))
            while target > last_prediction + 1:
                if (last_prediction + 1) in sentences:
                    print("#BOS %d" %(last_prediction + 1))
                    for (word, pos) in sentences[last_prediction + 1]:
                        print("%s\t%s\t--\t--\t500" %(word, pos))
                    print("#500\tNOPARSE\t--\t--\t0")
                    print("#EOS %d" %(last_prediction + 1))
                last_prediction = last_prediction + 1
            last_prediction = last_prediction + 1
        print(line.strip())