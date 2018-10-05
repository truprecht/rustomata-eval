# Parses the output of rparse and prints the parse trees to stdout
# and the parse time to stderr.

def format(l):
    return "%d\t%f\t%d" %(l[0], l[1], 1 if l[2] else 0)

if __name__ == "__main__":
    import re
    from sys import stdin

    time = re.compile(r"""finished in (\d+\.\d+)(?:E-(\d+))?""")
    fail = re.compile(r"""No parse found""")
    newl = re.compile(r"""Parsing \((\d+)\)""")

    last_parse = None

    for line in stdin:
        try:
            words = int(newl.match(line).group(1))
            if last_parse: print(format(last_parse))
            last_parse = [words, 0.0, True]
        except: pass
        try:
            c, e = time.match(line).group(1, 2)
            c = float(c)
            if e: c *= 10^(-float(e))
            last_parse[1] += c
        except: pass
        if fail.match(line):
            last_parse[2] = False
    if last_parse: print(format(last_parse))
