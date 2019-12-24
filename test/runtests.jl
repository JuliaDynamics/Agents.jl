using Test, Agents, Random

mutable struct Agent0 <: AbstractAgent
  id::Int
end

mutable struct Agent1 <: AbstractAgent
  id::Int
  pos::Tuple{Int,Int}
end

@testset "all tests" begin

include("api_tests.jl")
include("forest_fire_defs.jl")
include("space_test.jl")
include("data_collector_test.jl")
include("boltzmann_test.jl")
include("schelling_test.jl")
include("CA_test.jl")

end
