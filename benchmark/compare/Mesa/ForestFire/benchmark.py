# Use Python 3

import timeit
import gc

setup = f"""
gc.enable()
import os, sys
sys.path.insert(0, os.path.abspath("."))

from model import ForestFire

import random
random.seed(2)

def runthemodel(fire):
    for i in range(0, 100):
      fire.step()


fire = ForestFire()
"""

tt = timeit.Timer('runthemodel(fire)', setup=setup)
a = min(tt.repeat(100, 1))
print("Mesa ForestFire (ms):", a*1e3)

