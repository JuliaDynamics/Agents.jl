# 2D CA using Agents.jl

using Agents

mutable struct CA3 <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer}
  status::String
end

mutable struct CAWorld2 <: AbstractModel
  space::AbstractSpace
  agents::Array{AbstractAgent}
  scheduler::Function
  rules::Dict
end

mutable struct CAGrid2 <: AbstractSpace
  dimensions
  space
  agent_positions::Array  # an array of arrays for each grid node
end


# initialize the model
function ca_initiation(;rules::Dict, gridsize=(101,1))
  agents = [CA3(i, (i,1), "0") for i in 1:gridsize[1]]
  agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize[1]]
  mygrid = CAGrid2(gridsize, grid(gridsize, false, false), agent_positions)
  model = CAWorld2(mygrid, agents, as_added, rules)
  return model
end

rules = Dict("111"=>"0", "110"=>"0", "101"=>"0", "100"=>"1", "011"=>"1", "010"=>"1", "001"=>"1", "000"=>"0")  # rule 30
model = ca_initiation(rules=rules, gridsize=(101,1))
model.agents[50].status="1"

function ca_step!(model)
  agentnum = nagents(model)
  new_status = Array{String}(undef, agentnum)
  for agid in 1:agentnum
    agent = model.agents[agid]
    center = agent.status
    if agent.id == agentnum
      right = "0"
      left = model.agents[agent.id-1].status
    elseif agent.id == 1
      left = "0"
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


runs = 100
data = step!(dummystep, ca_step!, model, runs, [:pos, :status], collect(1:runs))

visualize_1DCA(data, model, :pos, :status, runs)