# # Social networks with LightGraphs.jl

# ![](play.gif)

# Many ABM frameworks provide graph infrastructure for analysing network properties of agents.
# Agents.jl is no different in that aspect, we have [`GraphSpace`](@ref) for when spatial structure
# is not important, but connections are.

# What if you wish to model something a little more complex? Perhaps a school yard full of students
# running around (in space), interacting via some social network. This is precisely the scenario that
# the [MASON](https://cs.gmu.edu/~eclab/projects/mason/) ABM framework uses as an introductory example
# in their [documentation](https://cs.gmu.edu/~eclab/projects/mason/manual.pdf).

# Rather than implementing an Agents.jl⸺specific graph structure, we can interface with
# [LightGraphs.jl](https://github.com/JuliaGraphs/LightGraphs.jl): a high class library for managing
# and implementing graphs, which can be re-used to establish social networks within existing spaces.

# To begin, we load in some dependencies

using Agents, LightGraphs, SimpleWeightedGraphs, SparseArrays, AgentsPlots, Random
gr() # hide

# And create a very simple agent.

mutable struct Student <: AbstractAgent
    id::Int
    pos::Tuple{Float64,Float64}
end

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
)
    model = ABM(
        Student,
        ContinuousSpace((100, 100), spacing; periodic = false);
        properties = Dict(
            :teacher_attractor => teacher_attractor,
            :noise => noise,
            :buddies => SimpleWeightedDiGraph(numStudents),
            :max_force => max_force,
        ),
    )
    for student in 1:numStudents
        ## Students begin near the school building
        add_agent!(model.space.extent .* 0.5 .+ Tuple(rand(2)) .- 0.5, model)

        ## Add one friend and one foe to the social network
        friend = rand(filter(s -> s != student, 1:numStudents))
        add_edge!(model.buddies, student, friend, rand())
        foe = rand(filter(s -> s != student, 1:numStudents))
        add_edge!(model.buddies, student, foe, -rand())
    end
    model
end

# Our model contains the `buddies` property, which is our LightGraphs.jl directed, weighted graph.
# As we can see in the loop, we choose one `friend` and one `foe` at random for each `student` and
# assign their relationship as a weighted edge on the graph.

# ## Movement dynamics

distance(pos) = sqrt(pos[1]^2 + pos[2]^2)
scale(L, force) = (L / distance(force)) .* force

function agent_step!(student, model)
    ## place a teacher in the center of the yard, so we don’t go too far away
    teacher = (model.space.extent .* 0.5 .- student.pos) .* model.teacher_attractor

    ## add a bit of randomness
    noise = model.noise .* (Tuple(rand(2)) .- 0.5)

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
# LightGraphs uses sparse vectors internally to efficiently represent data.
# When we find the `network` of our `student`, we want to convert the result to
# a dense representation by **find**ing the **n**on-**z**ero (`findnz`) elements.

# ## Visualising the system

# Now, we can watch the dynamics of the social system unfold:

Random.seed!(6548) #hide
model = schoolyard()
anim = @animate for i in 0:30
    i > 0 && step!(model, agent_step!, 1)
    p1 = plotabm(model; xlims = (0, 100), ylims = (0, 100), as = 7)
    scatter!(p1, [50], [50]; color = :red, legend = false) # Show position of teacher
    title!(p1, "step $(i)")
end
gif(anim, "play.gif", fps = 20)
