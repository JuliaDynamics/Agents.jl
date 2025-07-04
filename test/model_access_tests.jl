using Agents, Test

@testset "Model Access" begin
    @testset "Accessing model" begin
        @testset "ModelType=$(ModelType)" for ModelType in (StandardABM, EventQueueABM)
            @testset "ContainerType=$(ContainerType)" for ContainerType in (Dict, Vector, StructVector)

                extra_args = ifelse(ModelType != EventQueueABM, (), ((),))
                extra_kwargs = ifelse(ModelType != EventQueueABM, (warn_deprecation = false, ), ((autogenerate_on_add=false),))
                # For StructVector container, we need to wrap the agent type with SoAType
                agent_type = ContainerType == StructVector ? SoAType{NoSpaceAgent} : NoSpaceAgent
                model = ModelType(agent_type, extra_args...;
                    properties = Dict(:a => 2, :b => "test"),
                    container = ContainerType, extra_kwargs...
                )
                # Add agents differently based on container type
                for i in 1:5
                    if ContainerType == StructVector
                        add_agent!(NoSpaceAgent, model)
                    else
                        add_agent!(model)
                    end
                end
                if ModelType == StandardABM
                    @test abmscheduler(model) == Schedulers.fastest
                end

                @test abmtime(model) == 0
                @test abmproperties(model) == Dict(:a => 2, :b => "test")
                a = model[1]
                # Test based on container type
                if ContainerType == StructVector
                    @test a isa SoAType
                else
                    @test a isa NoSpaceAgent
                end
                @test a.id == 1
                @test model.a == 2
                @test model.b == "test"

                model.a = 7
                model.b = "Changed"
                @test model.a == 7
                @test model.b == "Changed"
                @test_throws ErrorException model.c = 5

                # Add a new agent
                if ContainerType == StructVector
                    newa = add_agent!(NoSpaceAgent, model)
                    @test model[6].id == newa.id
                else
                    newa = add_agent!(agent_type, model)
                    @test model[6] == newa
                end
                # setindex must errors
                @test_throws ErrorException model[7] = newa

                mutable struct Properties
                    par1::Int
                    par2::Float64
                    par3::String
                end
                properties = Properties(1,1.0,"Test")
                model = ModelType(agent_type, extra_args...; properties, container = ContainerType, extra_kwargs...)
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

                model = ModelType(agent_type, extra_args...; container = ContainerType, extra_kwargs...)
                @test_throws ErrorException model.a = 5
            end
        end
    end

    @testset "model access typestability" begin
        prop1 = Dict(:a => 0.5)
        struct TestContainer
            x::Int
            weight::Float64
        end
        prop2 = TestContainer(1, 0.5)
        model1 = StandardABM(NoSpaceAgent; properties = prop1, warn_deprecation = false)
        model2 = StandardABM(NoSpaceAgent; properties = prop2, warn_deprecation = false)
        model3 = StandardABM(SoAType{NoSpaceAgent}; properties = prop1, container = StructVector, warn_deprecation = false)
        add_agent!(NoSpaceAgent, model3)

        test1(model) = model.a
        test2(model) = model.weight
        @test_nowarn @inferred test1(model1)
        @test_nowarn @inferred test2(model2)
        @test_nowarn @inferred test1(model3)
    end

    @testset "Core methods" begin
        model = StandardABM(GridAgent{2}, GridSpace((5,5)), warn_deprecation = false)
        @test Agents.agenttype(model) == GridAgent{2}
        @test Agents.spacetype(model) <: GridSpace
        @test size(abmspace(model)) == (5,5)
        @test all(isempty(p, model) for p in positions(model))
        model_soa = StandardABM(SoAType{GridAgent{2}}, GridSpace((5,5)), container = StructVector, warn_deprecation = false)
        @test Agents.agenttype(model_soa) == GridAgent{2}
        @test Agents.spacetype(model_soa) <: GridSpace
        @test size(abmspace(model_soa)) == (5,5)
        @test all(isempty(p, model_soa) for p in positions(model_soa))
    end

    @testset "Display" begin
        using Agents.Graphs: path_graph
        model = StandardABM(NoSpaceAgent, warn_deprecation = false)
        @test occursin("no spatial structure", sprint(show, model))
        model = StandardABM(GridAgent{2}, GridSpace((5,5)), warn_deprecation = false)
        @test sprint(show, model)[1:25] == "StandardABM with 0 agents"
        @test sprint(show, Agents.abmspace(model)) == "GridSpace with size (5, 5), metric=chebyshev, periodic=true"
        model = StandardABM(ContinuousAgent{2}, ContinuousSpace((1.0,1.0)), warn_deprecation = false)
        @test sprint(show, Agents.abmspace(model)) == "periodic continuous space with [1.0, 1.0] extent and spacing=0.05"
        model = StandardABM(GraphAgent, GraphSpace(path_graph(5)), warn_deprecation = false)
        @test sprint(show, Agents.abmspace(model)) == "GraphSpace with 5 positions and 4 edges"
        model_soa = StandardABM(SoAType{NoSpaceAgent}, container = StructVector, warn_deprecation = false)
        @test occursin("no spatial structure", sprint(show, model_soa))
        @test occursin("agents container: StructVector", sprint(show, model_soa))
    end

end

@testset "SoAType Specific Tests" begin
    @testset "SoAType wrapper functionality with StandardABM" begin
        model = StandardABM(SoAType{NoSpaceAgent}, container = StructVector, warn_deprecation = false)
        for i in 1:3
            add_agent!(NoSpaceAgent, model)
        end
        # Test agent retrieval and wrapper behavior
        agent = model[1]
        @test agent isa SoAType
        @test getfield(agent, :id) == 1
        # Test property access and modification
        agent.id = 100
        @test model[1].id == 100
        # Test get/set property through the wrapper
        old_id = agent.id
        agent.id = 200
        @test agent.id == 200
        @test agent.id != old_id
        # Test the underlying StructVector
        soa = getfield(agent, :soa)
        @test soa isa StructVector
        @test soa.id[1] == 200
    end
    @testset "add_agent! with StructVector in StandardABM" begin
        model = StandardABM(SoAType{NoSpaceAgent}, container = StructVector, warn_deprecation = false)
        # Add an agent and verify it's accessible
        agent = add_agent!(NoSpaceAgent, model)
        @test agent isa NoSpaceAgent
        @test agent.id == 1
        # Test that they represent the same agent but aren't the same type
        wrapped_agent = model[1]
        @test wrapped_agent.id == agent.id
        @test typeof(wrapped_agent) != typeof(agent)
    end
    @testset "SoAType wrapper functionality with EventQueueABM" begin
        events = (AgentEvent((action!)=dummystep),)
        model = EventQueueABM(SoAType{NoSpaceAgent}, events, container=StructVector, autogenerate_on_add=false)
        for i in 1:3
            add_agent!(NoSpaceAgent, model)
        end
        agent = model[1]
        @test agent isa SoAType
        @test getfield(agent, :id) == 1
        agent.id = 100
        @test model[1].id == 100
        old_id = agent.id
        agent.id = 200
        @test agent.id == 200
        @test agent.id != old_id
        soa = getfield(agent, :soa)
        @test soa isa StructVector
        @test soa.id[1] == 200
    end
    @testset "add_agent! with StructVector in EventQueueABM" begin
        events = (AgentEvent((action!)=dummystep),)
        model = EventQueueABM(SoAType{NoSpaceAgent}, events, container=StructVector, autogenerate_on_add=false)
        agent = add_agent!(NoSpaceAgent, model)
        @test agent isa NoSpaceAgent
        @test agent.id == 1
        wrapped_agent = model[1]
        @test wrapped_agent.id == agent.id
        @test typeof(wrapped_agent) != typeof(agent)
    end
end