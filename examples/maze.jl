# # Maze Solver
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../maze.mp4" type="video/mp4">
# </video>
# ```
# Consider a scenario where a walker agent is stuck in a maze. Finding the shortest path through an
# arbitrary maze or map is simulated using a [`Pathfinder`](@ref) and its `walkable` map property.

# ## Setup
using Agents
using FileIO # To load images you also need ImageMagick available to your project

# The `Walker` agent needs no special property, just the `id` and `position` from [`@agent`](@ref).
@agent Walker GridAgent{2} begin end

# The maze is stored as a simple .bmp image, where each pixel corresponds to a position on the grid.
# White pixels correspond to walkable regions of the maze.
function initalize_model(map_url)
    ## Load the maze from the image file. White values can be identified by a
    ## non-zero red component
    maze = map(x -> x.r > 0, load(download(map_url)))
    ## Create a pathfinder by specifying the `walkable` parameter for the pathfinder.
    ## Since we are interested in the most direct path to the end, the default
    ## [`DirectDistance`](@ref) is appropriate.
    ## `diagonal_movement` is set to `false` to prevent cutting corners by going along
    ## diagonals.
    pathfinder = Pathfinder(walkable=maze, diagonal_movement=false)
    ## The size of the space is the size of the maze
    space = GridSpace(size(maze); pathfinder, periodic = false)
    model = ABM(Walker, space)
    ## Place a walker at the start of the maze
    walker = Walker(1, (1, 4))
    add_agent_pos!(walker, model)
    ## The walker's movement target is the end of the maze
    set_target!(walker, (41, 32), model)

    return model
end

## Dynamics
# Stepping the agent is a trivial matter of calling [`move_along_route!`](@ref) to move it along it's path to
# the target.
agent_step!(agent, model) = move_along_route!(agent, model)

# ## Visualization
# Visualizing the `Walker` move through the maze is handled through [`InteractiveDynamics.abm_plot`](@ref).
using InteractiveDynamics
using GLMakie
GLMakie.activate!() # hide

## Our sample walkmap
map_url =
    "https://raw.githubusercontent.com/JuliaDynamics/" *
    "JuliaDynamics/master/videos/agents/maze.bmp"
model = initalize_model(map_url)

# The `static_preplot!` keyword argument allows plotting the maze as a heatmap behind the agent.
abm_video(
    "maze.mp4",
    model,
    agent_step!;
    resolution=(700,700),
    frames=310,
    framerate=15,
    ac=:red,
    as=11,
    offset = _ -> (-0.5, -0.5),
    static_preplot! = (ax, _) -> heatmap!(ax, walkmap(model); colormap=:grays)
)
nothing # hide

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../maze.mp4" type="video/mp4">
# </video>
# ```
