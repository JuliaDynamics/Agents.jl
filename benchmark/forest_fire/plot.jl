# Run the benchmarks for Julia (run.jl) and Python (run.py). Copy the results in the vectors below and plot

using VegaLite
using DataFrames

# Agents.jl benchmark results
jlresults = [
0.124292399,
0.261890796,
0.382272875,
0.526156528,
0.643057459,
0.795138978,
1.012378349,
1.180964479,
1.248486157,
1.369958317]

# Mesa benchmark results
pyresults = [
0.9389688929659314,
1.9137998179649003,
2.9129630780080333,
4.070444974990096,
5.039975131978281,
6.156719513994176,
7.4113737950101495,
8.584513186011463,
10.217067367048003,
11.377028140006587
]

size_range = (100:100:1000) .* 100

dd = DataFrame(runtime=vcat(jlresults, pyresults), lang=vcat(["Agents.jl" for i in 1:10], ["Mesa" for i in 1:10]), gridsize=vcat(size_range, size_range));

@vlplot(data=dd,
  mark={:line,
    size=4,
    point={filled=false, fill="white", size=60}
  },
  x={:gridsize,
    type="ordinal",
    title="Grid size",
    axis={titleFontSize=16, labelFontSize=14},
    grid=true,
  },
  y={:runtime,
    type="quantitative",
    title="Run time (seconds)",
    axis={titleFontSize=13,
    labelFontSize=14},
    grid=true
  },
  color={:lang,
    type="nominal",
    title="Framework",
    legend={titleFontSize=15, labelFontSize=14},
    scale={range=["#EA98D2", "#659CCA"]},
  },
  height=400,
  width=500,
)

dd2 = DataFrame(ratio=pyresults./jlresults, gridsize=size_range);

@vlplot(data=dd2,
  mark={:bar},
  x={:gridsize,
    type="ordinal",
    title="Grid size",
    axis={titleFontSize=16, labelFontSize=14},
  },
  y={:ratio,
    type="quantitative",
    title="Mesa/Agents run time",
    axis={titleFontSize=13,
    labelFontSize=14}
  },
  height=400,
  width=500,
)