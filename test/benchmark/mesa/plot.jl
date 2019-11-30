# Run the benchmarks for Julia (run.jl) and Python (run.py). Copy the results in the vectors below and plot

using VegaLite
using DataFrames

# Agents.jl benchmark results
jlresults = [
0.0623855,
0.1409112,
0.2434189,
0.3797918]#,
# 0.8206902,
# 0.7178797,
# 0.9326405,
# 1.364939,
# 1.5469985,
# 2.051536]

# Mesa benchmark results
pyresults = [
0.8042,
1.9173,
3.1619,
4.7495
]

size_range = ((100:100:1000) .* 100)[1:4]

dd = DataFrame(runtime=vcat(jlresults, pyresults), lang=vcat(["Agents.jl" for i in 1:4], ["Mesa" for i in 1:4]), nv=vcat(size_range, size_range));

@vlplot(data=dd,
  mark={:line,
    size=4,
    point={filled=false, fill="white", size=60}
  },
  x={:nv,
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

dd2 = DataFrame(ratio=pyresults./jlresults, nv=size_range);

@vlplot(data=dd2,
  mark={:bar},
  x={:nv,
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