```@meta
EditURL = "<unknown>/../examples/game_of_life_2D_CA.jl"
```

# Two-dimensional cellular automata
Agents.jl provides a module (CA2D) to create and plot 2D cellular automata.

```@example game_of_life_2D_CA
using Agents
using AgentsPlots
using Agents.CA2D
```

## 1. Define the rule
Rules of Conway's game of life: DSR (Death, Survival, Reproduction).
Cells die if the number of their living neighbors are <D,
survive if the number of their living neighbors are <=S,
come to life if their living neighbors are as many as R.

```@example game_of_life_2D_CA
rules = (2,3,3)
```

## 2. Build the model
"CA2D.build_model" creates a model where all cells are by default off ("0")

```@example game_of_life_2D_CA
model = CA2D.build_model(rules=rules, dims=(100, 100), Moore=true)
```

Let's make some random cells on

```@example game_of_life_2D_CA
for i in 1:nv(model)
  if rand() < 0.1
    model.agents[i].status="1"
  end
end
```

## 3. Run the model and collect data and create an `Animation` object. `plot_CA2Dgif` is a function from `AgentsPlots` that creates the animation.

```@example game_of_life_2D_CA
runs = 10
anim = CA2D.ca_run(model, runs, plot_CA2Dgif);
nothing #hide
```

We can now save the animation to a gif.

```@example game_of_life_2D_CA
AgentsPlots.gif(anim, "game_of_life.gif")
```

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

