# Unescapes parse trees.

import re

terminal_escapes = [ (re.compile(pat), r) for (pat, r) in [
                        ("^MDASH$", lambda _: "--"),
                        ("DASH", lambda _: "-"),
                        ("SQ", lambda _: "'"),
                        ("DQ", lambda _: "\""),
                        ("BACKSLASH", lambda _: "\\"),
                        ("SLASH", lambda _: "/"),
                        ("COMMA", lambda _: ","),
                        ("PUNCT", lambda _: "."),
                        ("^LBR$", lambda _: "("),
                        ("^RBR$", lambda _: ")"),
                        ("LBR(.+)RBR", lambda x: "({0})".format(x.group(1)))
                    ] ]
def gf_unescape_terminal(word):
    for (regex, replacement) in terminal_escapes:
        word = regex.sub(replacement, word)
    return word

def gf_unescape_nonterminal(cat):
    return cat.replace("LBR", "$(") \
              .replace("COMMA", "$,") \
              .replace("PUNCT", "$.")

r_line = re.compile(r"""^([^\s]+)\s+([^\s]+)\s+--\s+--\s+(\d+)$""")
r_inner = re.compile(r""""^\#\d+$""")
r_pos_with_fanout = re.compile(r"""\d+$""")
def word_pos_substitution(match):
    (word, pos, parent) = match.groups()
    if not r_inner.match(word):
        word = gf_unescape_terminal(word)
    pos = gf_unescape_nonterminal(pos)
    pos = r_pos_with_fanout.sub(lambda _: "", pos)
    return "{}\t{}\t--\t--\t{}".format(word, pos, parent)


if __name__ == "__main__":
    from sys import stdin

    for line in stdin:
        print(r_line.sub(word_pos_substitution, line.strip()))