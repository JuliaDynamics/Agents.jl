# 1D CA using Agents.jl
module CA1D
using Agents

mutable struct Cell <: AbstractAgent
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
  model = ABM(Cell, space; properties = properties, scheduler=by_id)
  for n in 1:ncols
    add_agent!(Cell(n, (n,1), "0"), (n,1), model)
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

"""
    ca_run(model::ABM, runs::Integer)

Runs a 1D cellular automaton.
"""
function ca_run(model::ABM, runs::Integer)
  data = run!(model, dummystep, ca_step!, runs; acollect=[:pos, :status], when=1:runs)
end

end  # module
