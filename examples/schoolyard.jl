# # [Social networks with Graphs.jl](@id social_networks)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../schoolyard.mp4" type="video/mp4">
# </video>
# ```

# Many ABM frameworks provide graph infrastructure for implementing network-based interactions
# properties of agents. Agents.jl does not provide any graph infrastructure for network-based
# interactions because it doesn't have to!
# Since Agents.jl is implemented in Julia, it can integrate directly
# with Julia's premier package for graphs, Graphs.jl.

# _Note as mentioned in the documentation of [`GraphSpace`](@ref) that network-based
# interactions should not be modeled as a space, even though other ABM frameworks
# implement it as such as an only option!_

# In this example we will model the situation where there is both a network structure
# in agent interactions, but also a completely independent spatial structure in the model.
# We will model a school yard full of students
# running around (in space) _and_ interacting via some social network.

# To begin, we load in some dependencies

using Agents
using SimpleWeightedGraphs: SimpleWeightedDiGraph # will make social network
using SparseArrays: findnz                        # for social network connections
using Random: MersenneTwister                     # reproducibility

# And create an alias to `ContinuousAgent{2,Float64}`,
# as our agents don't need additional properties.
const Student = ContinuousAgent{2,Float64}

# ## Rules of the schoolyard

# It's lunchtime, and the students are going out to play.
# We assume the school building is in the centre of our space, with some fences around the building.
# A teacher monitors the students, and makes sure they don't stray too far towards the fence.
# We use a `teacher_attractor` force to simulate a teacher's attentiveness.
# Students head out to the schoolyard in random directions, but adhere to some social norms.

# Each student has one *friend* and one *foe*. These are chosen at random in our model, so it's
# possible that for any pair of students, one likes the other but this feeling is not reciprocated.
# The bond between pairs is chosen at random between 0 and 1, with a bond of 1 being the strongest.
# If the bond is *friendly*, agents wish above all else to be near their *friend*.
# Bonds that are *unfriendly* see students moving as far away as possible from their *foe*.

# ## Initialising the model

function schoolyard(;
        numStudents = 50,
        teacher_attractor = 0.15,
        noise = 0.1,
        max_force = 1.7,
        spacing = 4.0,
        seed = 6998,
        velocity = (0, 0),
    )
    model = StandardABM(
        Student,
        ContinuousSpace((100, 100); spacing=spacing, periodic=false);
        agent_step!,
        properties = Dict(
            :teacher_attractor => teacher_attractor,
            :noise => noise,
            ## This is the graph
            :buddies => SimpleWeightedDiGraph(numStudents),
            :max_force => max_force,
        ),
        rng = MersenneTwister(seed)
    )
    for student in 1:numStudents
        ## Students begin near the school building
        position = abmspace(model).extent .* 0.5 .+ rand(abmrng(model), SVector{2}) .- 0.5
        add_agent!(position, model, velocity)

        ## Add one friend and one foe to the social network
        friend = rand(abmrng(model), filter(s -> s != student, 1:numStudents))
        add_edge!(model.buddies, student, friend, rand(abmrng(model)))
        foe = rand(abmrng(model), filter(s -> s != student, 1:numStudents))
        add_edge!(model.buddies, student, foe, -rand(abmrng(model)))
    end
    model
end

# Our model contains the `buddies` property, which is our Graphs.jl directed and weighted graph.
# Here we chose one `friend` and one `foe` at random for each student` and assign their
# relationship as a weighted edge on the graph.
# By construction, the agent ID and graph node ID coincide.

# ## Movement dynamics

distance(pos) = sqrt(pos[1]^2 + pos[2]^2)
scale(L, force) = (L / distance(force)) .* force

function agent_step!(student, model)
    ## place a teacher in the center of the yard, so we don’t go too far away
    teacher = (abmspace(model).extent .* 0.5 .- student.pos) .* model.teacher_attractor

    ## add a bit of randomness
    noise = model.noise .* (rand(abmrng(model), SVector{2}) .- 0.5)

    ## Adhere to the social network
    network = model.buddies.weights[student.id, :]
    tidxs, tweights = findnz(network)
    network_force = (0.0, 0.0)
    for (widx, tidx) in enumerate(tidxs)
        buddiness = tweights[widx]
        force = (student.pos .- model[tidx].pos) .* buddiness
        if buddiness >= 0
            ## The further I am from them, the more I want to go to them
            if distance(force) > model.max_force # I'm far enough away
                force = scale(model.max_force, force)
            end
        else
            ## The further I am away from them, the better
            if distance(force) > model.max_force # I'm far enough away
                force = (0.0, 0.0)
            else
                L = model.max_force - distance(force)
                force = scale(L, force)
            end
        end
        network_force = network_force .+ force
    end

    ## Add all forces together to assign the students next position
    new_pos = student.pos .+ noise .+ teacher .+ network_force
    move_agent!(student, new_pos, model)
end

# Applying the rules for movement is relatively simple. For the network specifically,
# we find the student's `network` and figure out how far apart they are. We scale this
# by the `buddiness` factor (how much force we should apply), then figure out if
# that force should be in a positive or negative direction (*friend* or *foe*?).

# The `findnz` function is something that may require some further explanation.
# Graphs.jl uses sparse vectors internally to efficiently represent data.
# When we find the `network` of our `student`, we want to convert the result to
# a dense representation by **find**ing the **n**on-**z**ero (`findnz`) elements.

model = schoolyard()

# ## Visualising the system

# Now, we can watch the dynamics of the social system unfold:

using CairoMakie
CairoMakie.activate!() # hide

const ABMPlot = Agents.get_ABMPlot_type()
function Agents.preplot!(ax::Axis, p::ABMPlot)
    obj = CairoMakie.scatter!([50 50]; color = :red) # Show position of teacher
    CairoMakie.hidedecorations!(ax) # hide tick labels etc.
    CairoMakie.translate!(obj, 0, 0, 5) # be sure that the teacher will be above students
end

abmvideo(
    "schoolyard.mp4", model;
    framerate = 15, frames = 40,
    title = "Playgound dynamics",
)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../schoolyard.mp4" type="video/mp4">
# </video>
# ```
