cd(@__DIR__)
using Pkg; Pkg.activate(@__DIR__)
const CI = get(ENV, "CI", nothing) == "true"
CI && (ENV["GKSwstype"] = "100")
println("Loading Packages")
println("Documenter...")
using Documenter
println("Agents...")
using Agents
println("Literate...")
import Literate
println("InteractiveChaos...")
using InteractiveChaos
println("CairoMakie...")
import CairoMakie
println("OpenStreetMapX...")
import OpenStreetMapX

# %% Literate convertion
println("Converting Examples")
@info "Converting Examples to Docuementation"
indir = joinpath(@__DIR__, "..", "examples")
outdir = joinpath(@__DIR__, "src", "examples")
mkpath(outdir)
toskip = ("daisyworld_matrix.jl", "siroptim.jl")
for file in readdir(indir)
    file ∈ toskip && continue
    file ∉ ("schelling.jl", "opinion_spread.jl", "flock.jl", "forest_fire.jl") && continue
    Literate.markdown(joinpath(indir, file), outdir; credit = false)
end

# %%
# download the themes
println("Themeing")
using DocumenterTools: Themes
for file in ("juliadynamics-lightdefs.scss", "juliadynamics-darkdefs.scss", "juliadynamics-style.scss")
    download("https://raw.githubusercontent.com/JuliaDynamics/doctheme/master/$file", joinpath(@__DIR__, file))
end
# create the themes
for w in ("light", "dark")
    header = read(joinpath(@__DIR__, "juliadynamics-style.scss"), String)
    theme = read(joinpath(@__DIR__, "juliadynamics-$(w)defs.scss"), String)
    write(joinpath(@__DIR__, "juliadynamics-$(w).scss"), header*"\n"*theme)
end
# compile the themes
Themes.compile(joinpath(@__DIR__, "juliadynamics-light.scss"), joinpath(@__DIR__, "src/assets/themes/documenter-light.css"))
Themes.compile(joinpath(@__DIR__, "juliadynamics-dark.scss"), joinpath(@__DIR__, "src/assets/themes/documenter-dark.css"))

# %%
println("Documentation Build")
ENV["JULIA_DEBUG"] = "Documenter"
makedocs(modules = [Agents,InteractiveChaos],
sitename= "Agents.jl",
authors = "Ali R. Vahdati, George Datseris, Tim DuBois and contributors.",
doctest = false,
format = Documenter.HTML(
    prettyurls = CI,
    assets = [
        asset("https://fonts.googleapis.com/css?family=Montserrat|Source+Code+Pro&display=swap", class=:css),
        ],
    collapselevel = 1,
    ),
pages = [
    "Introduction" => "index.md",
    "Tutorial" => "tutorial.md",
    "Examples" => [
        "Overview" => "examples.md",
        "Schelling's segregation model" => "examples/schelling.md",
        # "Sugarscape" => "examples/sugarscape.md",
        # "SIR model for the spread of COVID-19" => "examples/sir.md",
        # "Continuous space social distancing for COVID-19" => "examples/social_distancing.md",
        # "Wealth distribution" => "examples/wealth_distribution.md",
        "Forest fire" => "examples/forest_fire.md",
        # "Conway's game of life" => "examples/game_of_life_2D_CA.md",
        # "Wright-Fisher model of evolution" => "examples/wright-fisher.md",
        # "Hegselmann-Krause opinion dynamics" => "examples/hk.md",
        "Flocking" => "examples/flock.md",
        # "Daisyworld" => "examples/daisyworld.md",
        # "Predator-Prey" => "examples/predator_prey.md",
        # "Bacteria Growth" => "examples/growing_bacteria.md",
        "Opinion spread" => "examples/opinion_spread.md",
        # "Battle Royale" => "examples/battle.md"
        ],
    "Predefined Models" => "models.md",
    "API" => "api.md",
    "Interactive application" => "interact.md",
    # "Ecosystem Integration" => [
    #     "BlackBoxOptim.jl" => "examples/optim.md",
    #     "DifferentialEquations.jl" => "examples/diffeq.md",
    #     "LightGraphs.jl" => "examples/schoolyard.md",
    #     "Measurements.jl" => "examples/measurements.md"
    #     ],
    "ABM Framework Comparison" => "comparison.md",
    "Developer Docs" => "devdocs.md"
    ],
)

@info "Deploying Documentation"
if CI
    deploydocs(
        repo = "github.com/JuliaDynamics/Agents.jl.git",
        target = "build",
        push_preview = true
    )
end

println("Finished")
