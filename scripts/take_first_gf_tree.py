# reads dot format from stdin and prints the first graph definition as
# a single line
#
# we use this to take the first parse tree given by grammatical framework
# which prints an endless stream of trees in dot format

if __name__ == "__main__":
    from sys import stdin
    first = True
    lines = []
    for line in stdin:
        if line.strip() == "graph {":
            if first: first = False
            else: break;
        lines.append(line.strip())
    print("%;;%".join(lines), end="")