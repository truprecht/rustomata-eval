from mpl_toolkits.mplot3d import Axes3D
import matplotlib.pyplot as plt
import numpy as np
import math

beams, candidates, precisions, recalls, fscores = [[]] * 5
with open("results/rustomata-ofcv-scores.txt") as scorefile:
    cells = [line.split() for line in scorefile if line.strip()]
    beams, candidates, precisions, recalls, fscores = np.transpose(cells).astype(np.float)
bottom = np.zeros_like(fscores)
width = depth = 1

fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')
ax.plot_trisurf([math.log(beam, 10) for beam in beams], [math.log(c, 10) for c in candidates], fscores, 
shade=True)

xlabels = [item.get_text() for item in ax.get_xticklabels()]
xlabels[0], xlabels[2], xlabels[4], xlabels[6] = ["100", "1000", "10000", "100000"]
ylabels = [item.get_text() for item in ax.get_xticklabels()]
ylabels[0], ylabels[2], ylabels[4], ylabels[6] = ["1", "10", "100", "1000"]

ax.set_xticklabels(xlabels)
ax.set_yticklabels(ylabels)

plt.show()
