push!(LOAD_PATH, "/mnt/Data/Documents/Agents")
#push!(LOAD_PATH, "D:\\projects\\Agents.jl\\")

using Documenter, Agents

makedocs(
  sitename="Agents.jl",
    pages = [
        "Introduction" => "index.md",
        "Examples" => [
          "Schelling's segregation model" => "schelling.md"
          "Boltzmann wealth distribution" => "boltzmann_example01.md",
          "Forest fire" => "forest_fire.md",
          "Cellular Automata" => "CA.md"
        ],
        "Built-in funtions" => "builtin_functions.md"
    ]
  
)

deploydocs(
	    repo = "github.com/kavir1698/Agents.jl.git",
   )
