# %% accessing model
@testset "Accessing model" begin
    model = ABM(Agent0; properties = Dict(:a => 2, :b => "test"))
    # add 5 aents
    for i in 1:5
        add_agent!(model)
    end
    @test model.scheduler == fastest
    @test typeof(model.agents) <: Dict
    @test model.space == nothing
    @test model.properties == Dict(:a => 2, :b => "test")
    a = model[1]
    @test a isa Agent0
    @test a.id == 1
    @test model.a == 2
    @test model.b == "test"


    newa = Agent0(6)
    model[6] = newa
    @test model[6] == newa
    @test_throws ArgumentError model[7] = newa

    prop2 = Agent2(1, 0.5)
    model2 = ABM(Agent0; properties = prop2)
    @test model2.weight == 0.5

end

@testset "model access typestability" begin
    prop1 = Dict(:a => 0.5)
    prop2 = Agent2(1, 0.5)
    model1 = ABM(Agent0; properties = prop1)
    model2 = ABM(Agent0; properties = prop2)

    test1(model) = model.a
    test2(model) = model.weight
    @test_nowarn @inferred test1(model1)
    @test_nowarn @inferred test2(model2)
end

@testset "Core methods" begin
    model = ABM(Agent3, GridSpace((5,5)))
    @test Agents.agenttype(model) == Agent3
    @test Agents.spacetype(model) <: GridSpace
    @test ne(model) == 40
    @test nv(model) == 25
    @test Agents.agent_positions(model) == Agents.agent_positions(model.space)
    @test size(model.space) == (5,5)
    @test all(isempty(n, model) for n in nodes(model))
end

@testset "Display" begin
    model = ABM(Agent3, GridSpace((5,5)))
    @test sprint(show, model) == "AgentBasedModel with 0 agents of type Agent3\n space: GridSpace with 25 nodes and 40 edges\n scheduler: fastest"
    @test sprint(show, model.space) == "GridSpace with 25 nodes and 40 edges"
    model = ABM(Agent6, ContinuousSpace(2))
    @test sprint(show, model.space) == "2-dimensional periodic ContinuousSpace"
end
