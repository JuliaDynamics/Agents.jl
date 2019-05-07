# 1D CA using Agents.jl
module CA1D
using Agents

mutable struct Agent{T<:Integer, Y<:AbstractString} <: AbstractAgent
  id::T
  pos::Tuple{T, T}
  status::Y
end

mutable struct Model{T<:AbstractVector, Y<:AbstractDict, X<:AbstractSpace} <: AbstractModel
  space::X
  agents::T  #Array{AbstractAgent}
  scheduler::Function
  rules::Y
end

mutable struct Space{T<:Integer, Y<:AbstractVector} <: AbstractSpace
  dimensions::Tuple{T, T}
  space::SimpleGraph
  agent_positions::Y  # an array of arrays for each grid node
end


"""
    build_model(;rules::Dict, ncols=101)

Builds a 1D cellular automaton. `rules` is a dictionary with this format: `Dict("000" => "0")`. `ncols` is the number of cells in a 1D CA.
"""
function build_model(;rules::Dict, ncols::Integer=101)
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

"""
    ca_run(model::AbstractModel, runs::Integer, filename::String="CA_1D")

Runs a 1D cellular automaton.
"""
function ca_run(model::AbstractModel, runs::Integer, filename::String="CA_1D")
  data = step!(dummystep, CA1D.ca_step!, model, runs, [:pos, :status], collect(1:runs))
  visualize_1DCA(data, model, :pos, :status, runs, savename=filename)
end

end  # module