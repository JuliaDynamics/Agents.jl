using Pkg
Pkg.activate(@__DIR__)
cd(@__DIR__)

using Documenter, Agents, DataFrames, Random, Statistics, SQLite
using Literate
using UnicodePlots
using Plots
using AgentsPlots
const CI = get(ENV, "CI", nothing) == "true"
CI && (ENV["GKSwstype"] = "100")

# %% Literate convertion
indir = joinpath(@__DIR__, "..", "examples")
outdir = joinpath(@__DIR__, "src", "examples")
for file in readdir(indir)
    Literate.markdown(joinpath(indir, file), outdir; credit = false)
end

# %%
# download the themes
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
cd(@__DIR__)
makedocs(modules = [Agents,AgentsPlots],
sitename= "Agents.jl",
authors = "Ali R. Vahdati, George Datseris and contributors.",
doctest = false,
format = Documenter.HTML(
    prettyurls = CI,
    assets = [
        asset("https://fonts.googleapis.com/css?family=Montserrat|Source+Code+Pro&display=swap", class=:css),
    ],
    ),
pages = [
    "Introduction" => "index.md",
    "Tutorial" => "tutorial.md",
    "Examples" => [
        "Schelling's segregation model" => "examples/schelling.md",
        "SIR model for the spread of COVID-19" => "examples/sir.md",
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
    deploydocs(
        repo = "github.com/JuliaDynamics/Agents.jl.git",
        target = "build",
        push_preview = true
    )
end


println("done")
