import os, sys
sys.path.insert(0, os.path.abspath(".."))
from agent import TreeCell
from model import ForestFire

# runnig the model
fire = ForestFire(100, 100, 0.6)

fire.run_model()
results = fire.dc.get_model_vars_dataframe()
