using Agents
@testset "Iterate over Agents" begin
    TESTSYSTEMSIZE = 10.

    @kwdef mutable struct TestAgent <: AbstractAgent
        id::Int
        pos::SVector{2,Float64}
        vel::SVector{2,Float64} = SVector(0., 0.)
    end

    test_space = ContinuousSpace((TESTSYSTEMSIZE, TESTSYSTEMSIZE))
    model_step!(model) = nothing
    test_model = StandardABM(TestAgent, test_space; model_step!)

    #direct adding leads to correct position
    add_agent!(SVector(0.5, 0.5), TestAgent, test_model)
    add_agent!(SVector(0.5, 0.1), TestAgent, test_model)

    #Debug Schedulker:
    scheduler = abmscheduler(test_model)
    @info "info: scheduler returns:" scheduler(test_model)

    #iter agent groups should return an iterable
    result = iter_agent_groups(2, test_model)
    @test Base.isiterable(typeof(result))


end