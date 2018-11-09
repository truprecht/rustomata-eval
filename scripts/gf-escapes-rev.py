# Unescapes parse trees.

import re

def gf_unescape(word):
    return word.replace("LBR", "(") \
               .replace("RBR", ")") \
               .replace("PUNCT", ".") \
               .replace("COMMA", ",") \
               .replace("MDASH", "--") \
               .replace("DASH", "-") \
               .replace("SLASH", "/") \
               .replace("BACKSLASH", "\\") \
               .replace("DQ", "\"") \
               .replace("SQ", "'")

r_line = re.compile(r"""^([^\s]+)\s+([^\s]+)\s+--\s+--\s+(\d+)$""")
r_inner = re.compile(r""""^\#\d+$""")
r_pos_with_fanout = re.compile(r"""\d+$""")
r_dollar_pos = re.compile(r"""\.|,|\(""")
def word_pos_substitution(match):
    (word, pos, parent) = match.groups()
    if not r_inner.match(word):
        word = gf_unescape(word)
    pos = gf_unescape(pos)
    pos = pos if not r_dollar_pos.match(pos) else "${}".format(pos)
    pos = r_pos_with_fanout.sub(lambda _: "", pos)
    return "{}\t{}\t--\t--\t{}".format(word, pos, parent)


if __name__ == "__main__":
    from sys import stdin

    for line in stdin:
        print(r_line.sub(word_pos_substitution, line.strip()))