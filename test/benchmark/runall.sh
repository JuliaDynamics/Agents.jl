#!/bin/bash

echo "Benchmarking Julia"
julia --project=../../ benchmark.jl

echo "Benchmarking NetLogo"
# Don't run above 8 threads otherwise errors will spit once the JVMs try
# to share the Backing Store and lock it
ws=$(parallel -j8 ::: $(printf './netlogo_ws.sh %.0s' {1..100}) | sort | head -n1)
echo "NetLogo WolfSheep (ms): "$ws

ws=$(parallel -j8 ::: $(printf './netlogo_s.sh %.0s' {1..100}) | sort | head -n1)
echo "NetLogo Schelling (ms): "$ws

ws=$(parallel -j8 ::: $(printf './netlogo_forest.sh %.0s' {1..100}) | sort | head -n1)
echo "NetLogo ForestFire (ms): "$ws

echo "Benchmarking Mesa"
python Mesa/WolfSheep/benchmark.py
#python Mesa/Flocking/benchmark.py
python Mesa/Schelling/benchmark.py
python Mesa/ForestFire/benchmark.py
