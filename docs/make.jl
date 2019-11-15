using Documenter, Agents, AgentsPlots

makedocs(
  sitename="Agents.jl",
    pages = [
        "Introduction" => "index.md",
        "Tutorial" => "tutorial.md",
        "Examples" => [
          "Boltzmann wealth distribution" => "boltzmann_example01.md",
          "Forest fire" => "forest_fire.md",
          "Cellular Automata" => "CA.md"
        ],
        "Built-in funtions" => "builtin_functions.md",
        "Comparison against Mesa" => "mesa.md"
    ]

)

deploydocs(
	    repo = "github.com/kavir1698/Agents.jl.git",
   )
