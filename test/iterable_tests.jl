using Agents
import Agents.Schedulers: fastest, Randomly, ByID, Partially, ByProperty, ByType
@testset "Iterate over Agents" begin
    TESTSYSTEMSIZE = 10.

    @kwdef mutable struct TestAgent <: AbstractAgent
        id::Int
        pos::SVector{2,Float64}
        vel::SVector{2,Float64} = SVector(0., 0.)
    end

    test_space = ContinuousSpace((TESTSYSTEMSIZE, TESTSYSTEMSIZE))
    model_step!(model) = nothing
    test_model = StandardABM(Agent6, test_space; model_step!)

    #direct adding leads to correct position
    add_agent!(SVector(0.5, 0.5), Agent6, test_model; vel=SVector(0.0, 0.0), weight=0)
    add_agent!(SVector(0.5, 0.1), Agent6, test_model; vel=SVector(0.0, 0.0), weight=0)

    #iter agent groups should return an iterable
    for scheduler in [fastest, Randomly(), ByID(), Partially(1), ByProperty(:weight)]
        @testset "Itermap with Scheduler: $scheduler" begin
            result = iter_agent_groups(2, test_model; scheduler)
            @test Base.isiterable(typeof(result))
            @test map_agent_groups(2, _ -> true, test_model; scheduler) |> all
        end
    end
end