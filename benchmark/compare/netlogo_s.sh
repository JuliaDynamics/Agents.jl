#!/bin/bash

# NetLogo's profiler sucks in the sense that it times one run, then spits out a bunch of junk
# to either a file or stdout. There's no easy abilitiy to parse it.

JAVA_HOME=/usr /opt/netlogo/netlogo-headless.sh --model "NetLogo/Schelling/Segregation.nlogo" --experiment benchmark | awk '/GO/{i++}i==2{print $3;exit}'
