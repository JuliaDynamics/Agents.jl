using Pkg
Pkg.activate(@__DIR__)

using Documenter, Agents, DataFrames, Random, Statistics
# using AgentsPlots

# %%
makedocs(modules = [Agents,],
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
	# "Examples" => [
	#   "Boltzmann wealth distribution" => "boltzmann_example01.md",
	#   "Forest fire" => "forest_fire.md",
	#   "Cellular Automata" => "CA.md"
	# 	],
	# "Comparison against Mesa" => "mesa.md"
    ],
)

if get(ENV, "CI", nothing) == "true"
    deploydocs(repo = "github.com/JuliaDynamics/Agents.jl.git",
               target = "build")
end
