# This scripts reads a given table, groups the entries by one given column name
# and prints aggregated columns (e.g. the sum of all entries in a group)
# of the original table.

import numpy as np
import pandas as p

def options(args):
    columns = { "ops": [], "group": None }
    for arg in args:
        if arg.startswith("--sum"):
            columns["ops"].append(("sum", arg.split("=")[1]))
        elif arg.startswith("--mean"):
            columns["ops"].append(("mean", arg.split("=")[1]))
        elif arg.startswith("--median"):
            columns["ops"].append(("median", arg.split("=")[1]))
        elif arg.startswith("--group"):
            if columns["group"]:
                raise Exception("you may specify only one group")
            columns["group"] = arg.split("=")[1]
    return columns

if __name__ == "__main__":
    from sys import argv, stdin
    help = """use %s [options]
              where options is a combination of:
                --sum=<index> - compute the sum of this column
                --mean=<index>
                --median=<index>
                --group=<index> group by this index""" % argv[0]
    if "--help" in argv:
        print(help)
        exit(0)

    opts = options(argv)
    
    table = p.read_table(stdin, index_col = opts["group"])
    for (_, col) in opts["ops"]:
        if "time" in col:
            table[col] = p.to_numeric(p.to_timedelta(table[col]))

    result = p.DataFrame(index = p.Index(np.unique(table.index), name=opts["group"]))
    table = table.groupby(opts["group"])
    
    for (op, col) in opts["ops"]:
        if op == "sum":
            collapsed = table[col].sum()
        elif op == "mean":
            collapsed = table[col].mean()
        elif op == "median":
            collapsed = table[col].median()
        if "time" in col:
            collapsed = collapsed / 1000000
        result = p.concat([result, collapsed], axis=1)
    print(result.to_csv(sep="\t"))