cd(@__DIR__)
using Pkg;
Pkg.activate(@__DIR__);
const CI = get(ENV, "CI", nothing) == "true"
println("Loading Packages")
println("Documenter...")
using Documenter
println("Agents...")
using Agents
println("Literate...")
import Literate
println("InteractiveDynamics...")
using InteractiveDynamics
println("LightOSM...")
using LightOSM

ENV["GKS_ENCODING"] = "utf-8"
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

# Also bring in visualizations from interactive dynamics docs:
using Literate
infile = joinpath(pkgdir(InteractiveDynamics), "docs", "src", "agents.jl")
outdir = joinpath(@__DIR__, "src")
Literate.markdown(infile, outdir; credit = false, name = "agents_visualizations")

# %%
# download the themes
println("Theme-ing")
using DocumenterTools:Themes
import Downloads
for file in (
    "juliadynamics-lightdefs.scss",
    "juliadynamics-darkdefs.scss",
    "juliadynamics-style.scss",
)
    Downloads.download(
        "https://raw.githubusercontent.com/JuliaDynamics/doctheme/master/$file",
        joinpath(@__DIR__, file),
    )
end
# create the themes
for w in ("light", "dark")
    header = read(joinpath(@__DIR__, "juliadynamics-style.scss"), String)
    theme = read(joinpath(@__DIR__, "juliadynamics-$(w)defs.scss"), String)
    write(joinpath(@__DIR__, "juliadynamics-$(w).scss"), header * "\n" * theme)
end
# compile the themes
Themes.compile(
    joinpath(@__DIR__, "juliadynamics-light.scss"),
    joinpath(@__DIR__, "src/assets/themes/documenter-light.css"),
)
Themes.compile(
    joinpath(@__DIR__, "juliadynamics-dark.scss"),
    joinpath(@__DIR__, "src/assets/themes/documenter-dark.css"),
)

# %%
println("Documentation Build")
ENV["JULIA_DEBUG"] = "Documenter"
makedocs(
    modules = [Agents, InteractiveDynamics, LightOSM],
    sitename = "Agents.jl",
    authors = "Tim DuBois, George Datseris, Aayush Sabharwal, Ali R. Vahdati and contributors.",
    doctest = false,
    format = Documenter.HTML(
        prettyurls = CI,
        assets = [
            asset(
                "https://fonts.googleapis.com/css?family=Montserrat|Source+Code+Pro&display=swap",
                class = :css,
            ),
        ],
        collapselevel = 1,
    ),
    pages = [
        "Introduction" => "index.md",
        "Tutorial" => "tutorial.md",
        "Examples" => [
            "Schelling's segregation model" => "examples/schelling.md",
            "SIR model for the spread of COVID-19" => "examples/sir.md",
            "Flocking" => "examples/flock.md",
            "Zombie Outbreak in a City" => "examples/zombies.md",
            "Predator-prey dynamics" => "examples/rabbit_fox_hawk.md",
            "Ecosystem with pathfinding" => "examples/rabbit_fox_hawk.md",
            "Predefined Models" => "models.md",
            "More Examples for Agents.jl" => "examples.md"
        ],
        "API" => "api.md",
        "Plotting and Interactivity" => "agents_visualizations.md",
        "Ecosystem Integration" => [
            "BlackBoxOptim.jl" => "examples/optim.md",
            "DifferentialEquations.jl" => "examples/diffeq.md",
            "Graphs.jl" => "examples/schoolyard.md",
            "Measurements.jl" => "examples/measurements.md",
        ],
        "Performance Tips" => "performance_tips.md",
        "ABM Framework Comparison" => "comparison.md",
        "Developer Docs" => "devdocs.md",
    ],
)

@info "Deploying Documentation"
if CI
    deploydocs(
        repo = "github.com/JuliaDynamics/Agents.jl.git",
        target = "build",
        push_preview = true,
    )
end

println("Finished")
