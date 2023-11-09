using Agents, Test

@testset "Model Access" begin
@testset "Accessing model" begin
    @testset "ModelType=$(ModelType)" for ModelType in (ABM, StandardABM, EventQueueABM)
        @testset "ContainerType=$(ContainerType)" for ContainerType in (Dict, Vector)
        model = ModelType(NoSpaceAgent; properties = Dict(:a => 2, :b => "test"), 
                          container = ContainerType, warn_deprecation = false)
        for i in 1:5
            add_agent!(model)
        end
        @test abmscheduler(model) == Schedulers.fastest
        @test abmproperties(model) == Dict(:a => 2, :b => "test")
        a = model[1]
        @test a isa NoSpaceAgent
        @test a.id == 1
        @test model.a == 2
        @test model.b == "test"

        model.a = 7
        model.b = "Changed"
        @test model.a == 7
        @test model.b == "Changed"
        @test_throws ErrorException model.c = 5

        newa = add_agent!(NoSpaceAgent, model)
        @test model[6] == newa
        # setindex must errors
        @test_throws ErrorException model[7] = newa

        mutable struct Properties
            par1::Int
            par2::Float64
            par3::String
        end
        properties = Properties(1,1.0,"Test")
        model = ModelType(NoSpaceAgent; properties, container = ContainerType, warn_deprecation = false)
        @test abmproperties(model) isa Properties
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

        model = ModelType(NoSpaceAgent, container = ContainerType, warn_deprecation = false)
        @test_throws ErrorException model.a = 5
        end
    end
end

@testset "model access typestability" begin
    prop1 = Dict(:a => 0.5)
    prop2 = Agent2(1, 0.5)
    model1 = StandardABM(NoSpaceAgent; properties = prop1, warn_deprecation = false)
    model2 = StandardABM(NoSpaceAgent; properties = prop2, warn_deprecation = false)

    test1(model) = model.a
    test2(model) = model.weight
    @test_nowarn @inferred test1(model1)
    @test_nowarn @inferred test2(model2)
end

@testset "Core methods" begin
    model = StandardABM(Agent3, GridSpace((5,5)), warn_deprecation = false)
    @test Agents.agenttype(model) == Agent3
    @test Agents.spacetype(model) <: GridSpace
    @test size(abmspace(model)) == (5,5)
    @test all(isempty(p, model) for p in positions(model))
end

@testset "Display" begin
    model = StandardABM(NoSpaceAgent, warn_deprecation = false)
    @test occursin("no spatial structure", sprint(show, model))
    model = StandardABM(Agent3, GridSpace((5,5)), warn_deprecation = false)
    @test sprint(show, model)[1:25] == "StandardABM with 0 agents"
    @test sprint(show, Agents.abmspace(model)) == "GridSpace with size (5, 5), metric=chebyshev, periodic=true"
    model = StandardABM(Agent6, ContinuousSpace((1.0,1.0)), warn_deprecation = false)
    @test sprint(show, Agents.abmspace(model)) == "periodic continuous space with [1.0, 1.0] extent and spacing=0.05"
    model = StandardABM(Agent5, GraphSpace(path_graph(5)), warn_deprecation = false)
    @test sprint(show, Agents.abmspace(model)) == "GraphSpace with 5 positions and 4 edges"
end

end
