# # Runners
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../runners.mp4" type="video/mp4">
# </video>
# ```
#
# Let's consider a race to the top of a mountain. Runners have been scattered about
# a map in some low lying areas and need to find the best path up to the peak.
#
# We'll use the [`AStar`](@ref) pathfinder and a [`HeightMap`](@ref) to simulate this.

# ## Setup
using Agents
using Random
using FileIO # To load images you also need ImageMagick available to your project

@agent Runner GridAgent{2} begin end

# Our agent, as you can see, is very simple. Just an `id` and `pos`ition provided by
# [`@agent`](@ref). The rest of the dynamics of this example will be provided by the model.

function initialise(map_url; goal = (128, 409), seed = 88)
    ## Load an image file and convert it do a simple representation of height
    heightmap = floor.(Int, convert.(Float64, load(download(map_url))) * 255)
    ## The space of the model can be obtained directly from the image.
    ## Our example file is (400, 500).
    space = GridSpace(size(heightmap), periodic = false)
    ## The pathfinder. We use the [`Chebyshev`](@ref) metric since we want the runners
    ## to look for the easiest path to run, not just the most direct.
    pf = AStar(space; cost_metric = HeightMap(heightmap, Chebyshev))
    model = ABM(Runner, space, pf; rng = MersenneTwister(seed))
    for _ in 1:10
        ## Place runners in the low-lying space in the map.
        runner = add_agent!((rand(model.rng, 100:350), rand(model.rng, 50:200)), model)
        ## Everyone wants to get to the same place.
        set_target!(runner, goal, model)
    end
    return model
end

# The example heightmap we use here is a small region of countryside in Sweden, obtained
# with the [Tangram heightmapper](https://github.com/tangrams/heightmapper).

# ## Dynamics
# With the pathfinder in place, and all our runners having a goal position set, stepping
# is now trivial.

agent_step!(agent, model) = move_agent!(agent, model)

# ## Let's Race
# Plotting is simple enough. We just need to use the [`InteractiveDynamics.abm_plot`](@ref)
# for our runners, and display the heightmap for our reference. A better interface to do
# this is currently a work in progress.
using InteractiveDynamics
using GLMakie
GLMakie.activate!() # hide

## Our sample heightmap
map_url =
    "https://raw.githubusercontent.com/JuliaDynamics/" *
    "JuliaDynamics/master/videos/agents/runners_heightmap.jpg"
model = initialise(map_url)

f, abmstepper = abm_plot(
    model;
    resolution = (700, 700),
    ac = :black,
    as = 8,
    scatterkwargs = (strokecolor = :white, strokewidth = 2),
)
ax = contents(f[1, 1])[1]
ax.aspect = DataAspect()
hm = heatmap!(ax, heightmap(model); colormap = :terrain)
f[1, 2] = Colorbar(f, hm, width = 30, label = "Elevation")
rowsize!(f.layout, 1, ax.scene.px_area[].widths[2]) # Colorbar height = axis height

record(f, "runners.mp4", 1:410; framerate = 25) do i
    Agents.step!(abmstepper, model, agent_step!, dummystep, 1)
end
nothing # hide

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../runners.mp4" type="video/mp4">
# </video>
# ```
