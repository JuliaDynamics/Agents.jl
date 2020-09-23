# Use Python 3

import timeit
import gc

setup = f"""
gc.enable()
import os, sys
sys.path.insert(0, os.path.abspath("."))

from model import SchellingModel

import random
random.seed(2)

def runthemodel(schelling):
    for i in range(0, 10):
      schelling.step()


schelling = SchellingModel()
"""

tt = timeit.Timer('runthemodel(schelling)', setup=setup)
a = min(tt.repeat(100, 1))
print("Mesa Schelling (ms):", a*1e3)

