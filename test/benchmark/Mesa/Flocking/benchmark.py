# Use Python 3

# Only collect the number of wolves and sheeps per step.

import timeit
import gc

setup = f"""
gc.enable()
import os, sys
sys.path.insert(0, os.path.abspath("."))

from model import BoidFlockers

def runthemodel(flock):
    for i in range(0, 100):
      flock.step()


flock = BoidFlockers()
"""

tt = timeit.Timer('runthemodel(flock)', setup=setup)
a = min(tt.repeat(100, 1))
print("Mesa Flocking (ms):", a*1e3)

