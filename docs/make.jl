using Pkg
Pkg.activate(@__DIR__)

using Documenter, Agents, DataFrames, Random, Statistics
using Literate
using UnicodePlots
using Plots
using AgentsPlots

# %% Literate convertion
indir = joinpath(@__DIR__, "..", "examples")
outdir = joinpath(@__DIR__, "src", "examples")
for file in ("forest_fire.jl", "wealth_distribution.jl",
			 "rule22_1D_CA.jl", "game_of_life_2D_CA.jl")
	Literate.markdown(joinpath(indir, file), outdir)
end

# %%
makedocs(modules = [Agents,AgentsPlots],
sitename= "Agents.jl",
authors = "Ali R. Vahdati, George Datseris and contributors.",
doctest = false,
format = Documenter.HTML(
    prettyurls = get(ENV, "CI", nothing) == "true",
    ),
pages = [
    "Introduction" => "index.md",
	"Tutorial" => "tutorial.md",
	"API" => "api.md",
	"Examples" => [
	  "Wealth distribution" => "examples/wealth_distribution.md",
		"Forest fire" => "examples/forest_fire.md",
		"Game of life" => "examples/game_of_life_2D_CA.md",
		"Rule 22" => "examples/rule22_1D_CA.md",
		],
	"Comparison against Mesa" => "mesa.md"
    ],
)

if get(ENV, "CI", nothing) == "true"
    deploydocs(repo = "github.com/JuliaDynamics/Agents.jl.git",
               target = "build")
end
