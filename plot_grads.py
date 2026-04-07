import pickle

import matplotlib.pyplot as plt
import numpy as np


with open("grads.pkl", "rb") as f:
    grads_tensor = pickle.load(f)

grads = []
for t in grads_tensor:
    grads.extend(t.flatten().tolist())


print(f"""
Mean: {np.mean(grads)}
Std: {np.std(grads)}
Count: {len(grads)}
""")


plt.hist(grads, bins=101)
plt.xlim(-0.02, 0.02)
plt.show()
