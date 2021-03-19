# # Mountain Runners
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../runners.mp4" type="video/mp4">
# </video>
# ```
#
# Let's consider a race to the top of a mountain. Runners have been scattered about
# a map in some low lying areas and need to find the best path up to the peak.
#
# We'll use [`Pathfinder`](@ref) and a [`HeightMap`](@ref) to simulate this.

# ## Setup
using Agents
using Random
using FileIO # To load images you also need ImageMagick available to your project

@agent Runner GridAgent{2} begin end

# Our agent, as you can see, is very simple. Just an `id` and `pos`ition provided by
# [`@agent`](@ref). The rest of the dynamics of this example will be provided by the model.

function initialize(map_url; goal = (128, 409), seed = 88)
    ## Load an image file and convert it do a simple representation of height
    heightmap = floor.(Int, convert.(Float64, load(download(map_url))) * 255)
    ## The space of the model can be obtained directly from the image.
    ## Our example file is (400, 500).

    ## The pathfinder. We use the `MaxDistance` metric since we want the runners
    ## to look for the easiest path to run, not just the most direct.
    pathfinder = Pathfinder(cost_metric = HeightMap(heightmap, MaxDistance{2}()))
    space = GridSpace(size(heightmap); pathfinder, periodic = false)
    model =
        ABM(Runner, space; rng = MersenneTwister(seed), properties = Dict(:goal => goal))
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

agent_step!(agent, model) = move_along_route!(agent, model)

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
model = initialize(map_url)

function preplot!(ax, model)
    ax.aspect = DataAspect()
    hm = heatmap!(ax, heightmap(model); colormap = :terrain)
    scatter!(ax, model.goal; color = (:red, 50), marker = 'x')
end

abm_video(
    "runners.mp4",
    model,
    agent_step!;
    resolution = (700, 700),
    frames = 410,
    framerate = 25,
    ac = :black,
    as = 8,
    scatterkwargs = (strokecolor = :white, strokewidth = 2),    
    static_preplot! = preplot!
)
nothing # hide

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../runners.mp4" type="video/mp4">
# </video>
# ```
