using Test, Agents, Random

@testset "all tests" begin

include("api_tests.jl")
include("forest_fire_defs.jl")
include("space_test.jl")
include("data_collector_test.jl")
include("boltzmann_test.jl")
include("schelling_test.jl")
include("CA_test.jl")

end