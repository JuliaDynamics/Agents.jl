# Set working directory
cd(@__DIR__)
println("Loading packages...")

# Function to import required packages with error handling
function import_packages()
    try
        using Agents
        using LightOSM
        using CairoMakie
        import Literate
    catch e
        println("Error importing packages: $e")
        # Optionally install missing packages here
    end
end
import_packages()

# Define pages structure for documentation
pages = [
    "Introduction" => "index.md",
    "Tutorial" => "tutorial.md",
    "Examples" => [
        "examples/sir.md",
        "examples/flock.md",
        "examples/zombies.md",
        "examples/predator_prey.md",
        "examples/rabbit_fox_hawk.md",
        "examples/event_rock_paper_scissors.md",
        "examples.md"
    ],
    "api.md",
    "Plotting and Interactivity" => "examples/agents_visualizations.md",
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
]

# Convert tutorial files with error handling
println("Converting tutorial...")
try
    Literate.markdown(
        joinpath(@__DIR__, "src", "tutorial.jl"), joinpath(@__DIR__, "src");
        credit = false
    )
catch e
    println("Error converting tutorial: $e")
end

# Convert examples with error handling
println("Converting Examples...")
indir = joinpath(@__DIR__, "..", "examples")
outdir = joinpath(@__DIR__, "src", "examples")

# Clean up previous examples only if directory exists
if isdir(outdir)
    rm(outdir; force = true, recursive = true)
end
mkpath(outdir)

toskip = ()
function convert_files(indir, outdir)
    tskip = Set(toskip)
    for file in readdir(indir)
        if file ∈ tskip
            println("Skipping $file")
            continue
        end
        try
            Literate.markdown(joinpath(indir, file), outdir; credit = false)
            println("Converted $file successfully.")
        catch e
            println("Error converting $file: $e")
        end
    end
end
convert_files(indir, outdir)

# Download style script with error handling
println("Downloading documentation style script...")
try
    Downloads.download(
        "https://raw.githubusercontent.com/JuliaDynamics/doctheme/master/build_docs_with_style.jl",
        joinpath(@__DIR__, "build_docs_with_style.jl")
    )
    include("build_docs_with_style.jl")
catch e
    println("Download or inclusion error: $e")
end

# Build documentation with error handling
println("Building documentation...")
try
    build_docs_with_style(pages, Agents, LightOSM;
        expandfirst = ["index.md"],
        authors = "George Datseris and contributors.",
        warnonly = true,
        htmlkw = (size_threshold = 20000 * 2^10, ),
    )
    println("Documentation build finished successfully.")
catch e
    println("Documentation build error: $e")
end

println("Finished")
