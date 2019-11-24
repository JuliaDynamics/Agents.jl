using Agents, Test

mutable struct Agent1 <: AbstractAgent
  id::Int
  pos::Tuple{Int,Int}
end
model1 = ABM(Agent1, Space((3,3)))

agent = add_agent!((1,1), model1)
