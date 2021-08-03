@testset "Model Access" begin
@testset "Accessing model" begin
    model = ABM(Agent0; properties = Dict(:a => 2, :b => "test"))
    for i in 1:5
        add_agent!(model)
    end
    @test model.scheduler == Schedulers.fastest
    @test typeof(model.agents) <: Dict
    @test model.space === nothing
    @test model.properties == Dict(:a => 2, :b => "test")
    a = model[1]
    @test a isa Agent0
    @test a.id == 1
    @test model.a == 2
    @test model.b == "test"

    model.a = 7
    model.b = "Changed"
    @test model.a == 7
    @test model.b == "Changed"
    @test_throws ErrorException model.c = 5

    newa = Agent0(6)
    model[6] = newa
    @test model[6] == newa
    @test_throws ArgumentError model[7] = newa

    prop2 = Agent2(1, 0.5)
    model2 = ABM(Agent0; properties = prop2)
    @test model2.weight == 0.5

    mutable struct Properties
        par1::Int
        par2::Float64
        par3::String
    end
    properties = Properties(1,1.0,"Test")
    model = ABM(Agent0; properties = properties)
    @test model.par1 == 1
    @test model.par2 == 1.0
    @test model.par3 == "Test"

    model.par1 = 7
    model.par2 = 7
    model.par3 = "Changed"
    @test model.par1 == 7
    @test model.par2 == 7.0
    @test model.par3 == "Changed"
    @test_throws ErrorException model.par4 = 5

    model = ABM(Agent0)
    @test_throws ErrorException model.a = 5
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
    @test size(model.space) == (5,5)
    @test all(isempty(p, model) for p in positions(model))
end

@testset "Display" begin
    model = ABM(Agent0)
    @test "nothing" in sprint(show, model)
    model = ABM(Agent3, GridSpace((5,5)))
    @test sprint(show, model)[1:29] == "AgentBasedModel with 0 agents"
    @test sprint(show, model.space) == "GridSpace with size (5, 5), metric=chebyshev, periodic=true"
    model = ABM(Agent6, ContinuousSpace((1,1), 0.1))
    @test sprint(show, model.space) == "periodic continuous space with 10×10 divisions"
    model = ABM(Agent5, GraphSpace(path_graph(5)))
    @test sprint(show, model.space) == "GraphSpace with 5 positions and 4 edges"
end

end
