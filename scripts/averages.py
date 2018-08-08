if __name__ == "__main__":
    from sys import argv, stdin
    help = """use %s (mean|median) <index> <group by index>""" % argv[0]
    assert len(argv) == 4, help

    values = {}
    for line in stdin:
        line = line.split()
        try: values[int(line[int(argv[3])])].append(float(line[int(argv[2])]))
        except: values[int(line[int(argv[3])])] = [float(line[int(argv[2])])]

    results = []
    for key in range(1, sorted(list(values.keys()))[-1] + 1):
        if argv[1] == "mean":
            results.append(sum(values[key]) / len(values[key]) if key in values else "na")
        elif argv[1] == "median":
            results.append(sorted(values[key])[int((len(values[key]) - 1) / 2)] if key in values else "na")
    
    print("\t".join([str(result) for result in results]))