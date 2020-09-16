#!/bin/bash

julia --project=../../ benchmark.jl

python Mesa/WolfSheep/benchmark.py
python Mesa/Flocking/benchmark.py

