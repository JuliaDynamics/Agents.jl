#push!(LOAD_PATH, "/mnt/Data/Documents/Agents")
push!(LOAD_PATH, "D:\\projects\\Agents.jl\\")

using Documenter, Agents

makedocs(
  sitename="Agents.jl",
    pages = [
        "Introduction" => "index.md",
        "Examples" => [
          "Boltzmann wealth distribution" => "boltzmann_example01.md",
        ],
        "Built-in funtions" => "builtin_functions.md"
    ]
  
)

deploydocs(
	    repo = "github.com/kavir1698/Agents.jl.git",
   )
