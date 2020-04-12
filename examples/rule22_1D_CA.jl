# # One-dimensional cellular automata

using Agents
using Agents.CA1D
using AgentsPlots

# ## 1. Define agent object and stepping function

mutable struct Cell1D <: AbstractAgent
  id::Int
  pos::Tuple{Int, Int}
  status::String
end

"""
    build_model(;rules::Dict, ncols=101)

Builds a 1D cellular automaton. `rules` is a dictionary with this format: `Dict("000" => "0")`. `ncols` is the number of cells in a 1D CA.
"""
function build_model(;rules::Dict, ncols::Integer=101)
  nv=(ncols,1)
  space = GridSpace(nv)
  properties = Dict(:rules => rules)
  model = ABM(Cell1D, space; properties = properties, scheduler=by_id)
  for n in 1:ncols
    add_agent!(Cell1D(n, (n,1), "0"), (n,1), model)
  end
  return model
end

function ca_step!(model)
  agentnum = nagents(model)
  new_status = Array{String}(undef, agentnum)
  for agid in 1:agentnum
    agent = model.agents[agid]
    center = agent.status
    if agent.id == agentnum
      # right = "0"  # this is for when there space is not toroidal
      right =  model.agents[1].status
      left = model.agents[agent.id-1].status
    elseif agent.id == 1
      # left = "0"  # this is for when there space is not toroidal
      left = model.agents[agentnum].status
      right = model.agents[agent.id+1].status
    else
      left = model.agents[agent.id-1].status
      right = model.agents[agent.id+1].status
    end
    rule = left*center*right
    new_status[agid] = model.properties[:rules][rule]
  end
  for ss in 1:agentnum
    model.agents[ss].status = new_status[ss]
  end
end

# ## 2. Define the rule
# Here is Wolfram's rule 22

rules = Dict(
    "111" => "0",
    "110" => "0",
    "101" => "0",
    "100" => "1",
    "011" => "0",
    "010" => "1",
    "001" => "1",
    "000" => "0",
);

# ## 2. Build the model
# All the cells are by default initially "off"
model = build_model(rules = rules, ncols = 21)

# This turns on the middle cell
model.agents[11].status = "1";

# ## 3. Run the model and collect data.
runs = 20
data, _ = run!(model, dummystep, ca_step!, runs; agent_properties=[:pos, :status], when=1:runs);


runs = 30
as(x) = 1.5
ac(x) = x[1].status == "1" ? :black : :white
am(x) = :square
anim = @animate for i in 1:runs
    step!(model, dummystep, ca_step!, 1)
    p1 = plotabm(model; ac=ac, as=as, am=am)
end

# We can now save the animation to a gif.

AgentsPlots.gif(anim, "rule22.gif")


