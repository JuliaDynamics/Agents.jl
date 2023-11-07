
using Agents, Random, DataStructures

# define the three agent types
@agent struct Rock(GridAgent{2})
end
@agent struct Paper(GridAgent{2})
end
@agent struct Scissors(GridAgent{2})
end

# Define the possible events
function selection!(agent, model)
    contender = random_nearby_agent(agent, model)
    if !isnothing(contender)
        pos_contender = contender.pos
        if agent isa Rock && contender isa Scissors
            remove_agent!(contender, model)
        elseif agent isa Scissors && contender isa Paper
            remove_agent!(contender, model)
        elseif agent isa Paper && contender isa Rock
            remove_agent!(contender, model)
        end
    end
    return
end

function reproduce!(agent, model)
    pos = random_nearby_position(agent, model, 1, pos -> isempty(pos, model))
    isnothing(pos) && return
    add_agent!(pos, typeof(agent), model)
    return
end

function swap!(agent, model)
    rand_pos = random_nearby_position(agent.pos, model)
    if isempty(rand_pos, model)
        move_agent!(agent, rand_pos, model)
    else
        near = model[id_in_position[rand_pos]]
        swap_agents!(agent, near, model)
    end
    return
end

# Put agents and events in the format required
agent_types = (Rock, Paper, Scissors) # internally this will be made `Union`
# events
rock_events = (selection!, reproduce!, swap!)
scissor_events = (selection!, reproduce!, swap!)
# paper dynamics have no movement
paper_events = (selection!, reproduce!)
# same layout as agent types
all_events = (rock_events, scissor_events, paper_events)

# rates:
# the length of each of these needs to be the same as the length of event tuples
rock_rates = (0.5, 0.5, 0.2) # relative proportionality matters only
paper_rates = (0.5, 0.2, 0.1)
scissor_rates = (0.5, 0.1)
# same layout as agent types
all_rates = (rock_rates, paper_rates, scissor_rates)

# Create model
space = GridSpaceSingle((100, 100))

rng = Xoshiro(42)
model = EventQueueABM(Union{Rock, Paper, Scissors}, space; all_events, all_rates, rng)

for p in positions(model)
	add_agent!(p, rand(rng, agent_types), model)
end

for a in values(Agents.agent_container(model))
	DataStructures.enqueue!(abmqueue(model), Agents.Event(a.id, 1) => rand(abmrng(model)))
end

step!(model, 1.32)

for a in values(Agents.agent_container(model))
	DataStructures.enqueue!(getfield(model, :queue), Agents.Event(a.id, 1) => rand(abmrng(model)))
end

step!(model, 1.32)
