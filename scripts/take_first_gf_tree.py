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