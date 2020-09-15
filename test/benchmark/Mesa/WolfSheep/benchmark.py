# Use Python 3

# Only collect the number of wolves and sheeps per step.

import timeit
import gc

setup = f"""
gc.enable()
import os, sys
sys.path.insert(0, os.path.abspath("."))

from agents import Sheep, Wolf, GrassPatch
from schedule import RandomActivationByBreed
from model import WolfSheep

wolfsheepmodel = WolfSheep()
"""

for a in range(0, 10):
    tt = timeit.timeit('wolfsheepmodel.run_model()', setup=setup, number=1)
    print(tt)

