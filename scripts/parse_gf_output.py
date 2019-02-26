# Parses the output of GF and prints the parse trees in bracket format
# to stdout and the parse time to stderr.

from sys import stderr
import re
from panda.general_hybrid_tree import HybridTree
from panda.monadic_tokens import construct_constituent_token
from panda.negra_parse import hybridtree_to_sentence_name, generate_ids_for_inner_nodes

def remove_dummy_pos(tree):
    ntree = HybridTree()
    pos_idxs = dict()
    for idx in tree.full_yield():
        token = tree.node_token(idx)
        ptoken = tree.node_token(tree.parent(idx))
        pos_idxs[tree.parent(idx)] = idx
        ntoken = construct_constituent_token(token.form(), ptoken.category(), True)
        ntree.add_node(idx, ntoken, True)
    for idx in tree.nodes():
        if idx in pos_idxs:
            ntree.add_child(tree.parent(idx), pos_idxs[idx])
            if idx in tree.root:
                ntree.add_to_root(pos_idxs[idx])
        elif idx in tree.full_yield():
            continue
        else:
            ntree.add_node(idx, tree.node_token(idx), False)
            ntree.add_child(tree.parent(idx), idx)
            if idx in tree.root:
                ntree.add_to_root(idx)
    return ntree

def gfdot_to_negra(s_):
    tree = HybridTree()
    i = 0
    for line in s_:
        match = re.search(r'(n\d+)\[label="([^\s]+)"\]', line)
        if match:
            (node_id, label) = match.group(1, 2)
            order = int(node_id[1:]) >= 100000
            if order:
                tree.add_node(node_id, construct_constituent_token(form=label, pos='_', terminal=True), True)
                i += 1
            else:
                tree.add_node(node_id, construct_constituent_token(form=label, pos='_', terminal=False), False)
            if label == 'VROOT1':
                tree.add_to_root(node_id)
            continue
        match = re.search(r'^(n\d+) -- (n\d+) \[style = "(?:dashed|solid)"\]$', line)
        if match:
            (parent, child) = match.group(1, 2)
            tree.add_child(parent, child)
    tree = remove_dummy_pos(tree)
    idNum = {}
    for root in tree.root:
        generate_ids_for_inner_nodes(tree, root, idNum)
    return '\n'.join(hybridtree_to_sentence_name(tree, idNum))

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

def print_noparse(wplist, id):
    print("#BOS {}".format(id))
    for (word, pos) in wplist:
        print("%s\t%s\t--\t--\t500" %(word, pos))
    print("#500\tNOPARSE\t--\t--\t0")
    print("#EOS {}".format(id))

if __name__ == "__main__":
    import re
    from sys import stdin, argv

    assert len(argv) == 2, "use %s <sentence file>" %argv[0]

    time = re.compile(r"""^(\d+ ms)ec$""")
    tree = re.compile(r"""^graph \{""")
    sentence = re.compile(r"""^(\d+)\s+(.*)$""") 
    word_pos = re.compile(r"""([^\s]+)/([^\s/]+)""")
    sentences = []
    ids = []
    with open(argv[1]) as sentence_file:
        for line in sentence_file:
            if line.strip():
                id, words = sentence.match(line).group(1, 2)
                sentences.append([(gf_escape(pos), gf_escape(word)) for (pos, word) in  word_pos.findall(words)])
                ids.append(id)

    last_passed = False
    index = 0
    for line in stdin:
        if not line.strip(): continue
        timem = time.match(line)
        treem = tree.match(line)
        if timem:
            if not last_passed: print_noparse(sentences[index], ids[index])
            eprint( "%d\t%s\t%d" %(len(sentences[index]), timem.group(1), 1 if last_passed else 0) )
            index += 1
            last_passed = False
        elif treem:
            print("#BOS {}".format(ids[index]))
            print(gfdot_to_negra(line.split("%;;%")))
            print("#EOS {}".format(ids[index]))
            last_passed = True