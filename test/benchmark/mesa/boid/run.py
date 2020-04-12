# Use Python 3

import timeit

setup = f"""
gc.enable()
import os, sys
sys.path.insert(0, os.path.abspath("."))
from model import BoidFlockers
import random
random.seed(2)
model = BoidFlockers(100, 100, 100, speed=5, vision=5, separation=1)

def runthemodel(model):
  for i in range(100):
    model.step()
"""

tt = timeit.Timer('runthemodel(model)', setup=setup)
a = min(tt.repeat(100, 1))
print(a)


