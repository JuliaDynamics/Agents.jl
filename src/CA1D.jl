# 1D CA using Agents.jl
module CA1D
using Agents

mutable struct Agent <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer}
  status::String
end

mutable struct Model <: AbstractModel
  space::AbstractSpace
  agents::Array{AbstractAgent}
  scheduler::Function
  rules::Dict
end

mutable struct Space <: AbstractSpace
  dimensions
  space
  agent_positions::Array  # an array of arrays for each grid node
end


# initialize the model
function build_model(;rules::Dict, ncols=101)
  gridsize=(ncols,1)
  agents = [Agent(i, (i,1), "0") for i in 1:gridsize[1]]
  agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize[1]]
  mygrid = Space(gridsize, grid(gridsize, true, false), agent_positions)
  # mygrid = Space(gridsize, grid(gridsize, false, false), agent_positions)  # this is for when there space is not toroidal
  model = Model(mygrid, agents, as_added, rules)
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
    new_status[agid] = model.rules[rule]
  end
  for ss in 1:agentnum
    model.agents[ss].status = new_status[ss]
  end
end

function ca_run(model::AbstractModel, runs::Integer, filename::String="CA1D")
  data = step!(dummystep, CA1D.ca_step!, model, runs, [:pos, :status], collect(1:runs))
  visualize_1DCA(data, model, :pos, :status, runs, savename=filename)
end

end  # module