using Pkg
Pkg.activate(@__DIR__)
cd(@__DIR__)

using Documenter, Agents, DataFrames, Random, Statistics
using Distributions # for the HK opinion example
using Literate
using UnicodePlots
using Plots
using AgentsPlots
const CI = get(ENV, "CI", nothing) == "true"
CI && (ENV["GKSwstype"] = "100")

# %% Literate convertion
indir = joinpath(@__DIR__, "..", "examples")
outdir = joinpath(@__DIR__, "src", "examples")
for file in ("schelling.jl", "forest_fire.jl", "wealth_distribution.jl",
			 "rule22_1D_CA.jl", "game_of_life_2D_CA.jl", "wright-fisher.jl",
			 "HK.jl")
	Literate.markdown(joinpath(indir, file), outdir; credit = false)
end

# %%
cd(@__DIR__)
makedocs(modules = [Agents,AgentsPlots],
sitename= "Agents.jl",
authors = "Ali R. Vahdati, George Datseris and contributors.",
doctest = false,
format = Documenter.HTML(
    prettyurls = CI,
    ),
pages = [
    "Introduction" => "index.md",
	"Tutorial" => "tutorial.md",
	"Examples" => [
		"Schelling's segregation model" => "examples/schelling.md",
		"Wealth distribution" => "examples/wealth_distribution.md",
		"Forest fire" => "examples/forest_fire.md",
		"Game of life" => "examples/game_of_life_2D_CA.md",
		"Rule 22" => "examples/rule22_1D_CA.md",
		"Wright-Fisher model of evolution" => "examples/wright-fisher.md",
		"Hegselmann-Krause opinion dynamics" => "examples/HK.md",
		],
	"API" => "api.md",
	"Comparison against Mesa (Python)" => "mesa.md"
    ],
)

if CI
    deploydocs(repo = "github.com/JuliaDynamics/Agents.jl.git",
               target = "build")
end
