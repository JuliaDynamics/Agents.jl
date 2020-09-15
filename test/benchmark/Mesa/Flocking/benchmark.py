# Use Python 3

# Only collect the number of wolves and sheeps per step.

import timeit
import gc

setup = f"""
gc.enable()
import os, sys
sys.path.insert(0, os.path.abspath("."))

from model import BoidFlockers

import random
random.seed(2)

def runthemodel(flock):
    for i in range(0, 1000):
      flock.step()


flock = BoidFlockers()
"""

for a in range(0, 10):
    tt = timeit.timeit('runthemodel(flock)', setup=setup, number=1)
    print(tt)

