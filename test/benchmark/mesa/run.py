# Use Python 3

import timeit

results = []
for width in range(100, 1100, 100):
  setup = f"""
gc.enable()
import os, sys
sys.path.insert(0, os.path.abspath("."))
from agent import TreeCell
from model import ForestFire
import random
random.seed(2)

def runthemodel(forest):
    for i in range(100):
      forest.step()
    results = forest.datacollector.get_model_vars_dataframe()


forest = ForestFire(100, {width}, 0.6)
  """

  tt = timeit.Timer('runthemodel(forest)', setup=setup)
  a = min(tt.repeat(100, 1))
  print(a)
  print('\n')
  results.append(a)


print(results)

# 0.8042
# 1.9173
# 3.1619
# 4.7495

"""
Update mesa 0.8.6 12.4.2020
0.8553307999998196
2.0069307999999637
3.3087123000000247
4.781681599999956
"""
