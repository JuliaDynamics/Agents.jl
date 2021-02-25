# # Maze
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../maze.mp4" type="video/mp4">
# </video>
# ```
# Consider a scenario where a walker agent are stuck in a maze. Finding the shortest path through an
# Arbitrary maze or map is simulated using the [`AStar`](@ref) pathfinder and it's `walkable` map property.

# ## Setup
using Agents
using Random
using FileIO # To load images you also need ImageMagick available to your project

# The `Walker` agent needs no special property, just the `id` and `position` from [`@agent`](@ref).
# The `Wall` agent is only for visualization purposes. It isn't involved in pathfinding
@agent Walker GridAgent{2} begin end
@agent Wall GridAgent{2} begin end

# The maze is stored as a simple .bmp image, where each pixel corresponds to a position on the grid.
# White pixels correspond to walkable regions of the maze. To initialize the model, a `Walker` is placed 
# at the entrance to the maze and `Wall`s wherever the maze is not walkable.
function initialize_model(; map_path="maze.bmp", seed=42)
    ## Load the maze from the image file. White values can be identified by a non-zero red component
    maze = map(x->x.r > 0, load(map_path))
    ## The size of the space is the size of the maze
    space = GridSpace(size(maze); periodic = false)
    ## Create a pathfinder by specifying the `walkable` parameter for the pathfinder.
    ## Since we are interested in the most direct path to the end, the default [`DirectDistance`](@ref)
    ## is appropriate.`moore_neighbors` is set to `false` to prevent cutting corners by going along diagonals.
    pathfinder = AStar(space; walkable = maze, moore_neighbors=false)
    model = ABM(Union{Walker,Wall}, space, pathfinder; rng=MersenneTwister(seed), warn=false)
    ## Place a walker at the start of the maze
    walker = Walker(1, (1,4))
    add_agent_pos!(walker, model)
    set_target!(walker, (41, 32), model) ## The walker's movement target is the end of the maze

    ## Add Walls wherever maze is false
    for i in 1:41, j in 1:41
        maze[i, j] || add_agent_pos!(Wall(nextid(model), (i, j)), model)
    end
    return model
end

## Dynamics
# Stepping the agent is a trivial matter of calling [`move_agent!`](@ref) to move it along it's path to
# the target.
agent_step!(agent, model) = move_agent!(agent, model)

# ## Visualization 
# Visualizing the `Walker` move through the maze is handled through [`InteractiveDynamics.abm_video`](@ref).
using InteractiveDynamics
import CairoMakie

color(a::Wall) = :black
color(a::Walker) = :red
mark(a::Wall) = '⬛'
mark(a::Walker) = '⬤'
sizeof(a::Wall) = 19
sizeof(a::Walker) = 10

# ```julia
# model = initialise()
# ```

model =  initialize_model(map_path = joinpath(@__DIR__, "../../../examples/maze.bmp")) # hide

abm_video("maze.mp4", model, agent_step!; ac=color, am=mark, as=sizeof, frames=310)
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../maze.mp4" type="video/mp4">
# </video>
# ```