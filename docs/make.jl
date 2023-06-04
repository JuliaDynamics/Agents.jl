cd(@__DIR__)
println("Loading packages...")
using Agents
import Literate
using LightOSM
using CairoMakie

pages = [
    "Introduction" => "index.md",
    "Tutorial" => "tutorial.md",
    "Examples" => [
        "examples/schelling.md",
        "examples/sir.md",
        "examples/flock.md",
        "examples/zombies.md",
        "examples/predator_prey.md",
        "examples/rabbit_fox_hawk.md",
        # "models.md", # I'm removing this from the docs; will be deprecated in the future
        "examples.md"
    ],
    "api.md",
    "Plotting and Interactivity" => "agents_visualizations.md",
    "Ecosystem Integration" => [
        "BlackBoxOptim.jl" => "examples/optim.md",
        "DifferentialEquations.jl" => "examples/diffeq.md",
        "Graphs.jl" => "examples/schoolyard.md",
        "Measurements.jl" => "examples/measurements.md",
        "CellListMap.jl" => "examples/celllistmap.md",
    ],
    "performance_tips.md",
    "comparison.md",
    "devdocs.md",
],


# %%

println("Converting Examples...")

indir = joinpath(@__DIR__, "..", "examples")
outdir = joinpath(@__DIR__, "src", "examples")
rm(outdir; force = true, recursive = true) # cleans up previous examples
mkpath(outdir)
toskip = ()
for file in readdir(indir)
    file ∈ toskip && continue
    Literate.markdown(joinpath(indir, file), outdir; credit = false)
end

# %%
println("Documentation Build")

import Downloads
Downloads.download(
    "https://raw.githubusercontent.com/JuliaDynamics/doctheme/master/build_docs_with_style.jl",
    joinpath(@__DIR__, "build_docs_with_style.jl")
)
include("build_docs_with_style.jl")

build_docs_with_style(pages, Agents, LightOSM;
    expandfirst = ["index.md"],
    authors = "George Datseris and contributors.",
)

println("Finished")
