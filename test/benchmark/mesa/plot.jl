# Run the benchmarks for Julia (run.jl) and Python (run.py). Copy the results in the vectors below and plot

using VegaLite
using DataFrames

# Agents.jl benchmark results
jlresults = [
 0.0639249,
 0.142405601,
 0.257741999,
 0.371782101]#,
#  0.5058402,
#  0.606949,
#  0.7233231,
#  1.056618399,
#  1.2427522,
#  1.5567561]

# Mesa benchmark results
pyresults = [
0.8553307999998196,
2.0069307999999637,
3.3087123000000247,
4.781681599999956
]

size_range = ((100:100:1000) .* 100)[1:4]

dd = DataFrame(runtime=vcat(jlresults, pyresults), lang=vcat(["Agents.jl 3.0" for i in 1:4], ["Mesa 0.8.6" for i in 1:4]), nv=vcat(size_range, size_range));

p1 = @vlplot(data=dd,
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
save("benchmark01.png", p1)

dd2 = DataFrame(ratio=pyresults./jlresults, nv=size_range);

p2=@vlplot(data=dd2,
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