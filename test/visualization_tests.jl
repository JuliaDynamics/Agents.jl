using Agents
using CairoMakie
using OSMMakie
using GraphMakie
using Test

@testset "plotting" begin
    # Here's the idea: for each space, we create a minimal model
    # and just call `abmplot`, seeing if it errors or not. If not, tests pass.
    function add_random_agents!(model, n = 5)
        for _ in 1:n
            add_agent!(model)
        end
        return model
    end
    dummy_step!(agent, model) = nothing

    @testset "GridSpace" begin
        model = StandardABM(GridAgent{2}, GridSpace((10, 10)); agent_step! = dummy_step!)
        add_random_agents!(model)
        fig, _ = abmplot(model)
        @test true
    end

    @testset "ContinuousSpace" begin
        @kwdef mutable struct ContiAgent <: AbstractAgent
            id::Int
            pos::SVector{2, Float64}
        end
        model = StandardABM(ContiAgent, ContinuousSpace((10, 10)); agent_step! = dummy_step!)
        add_random_agents!(model)
        fig, _ = abmplot(model)
        @test true
    end

    @testset "GraphSpace" begin
        g = Agents.Graphs.complete_graph(5)
        model = StandardABM(GraphAgent, GraphSpace(g); agent_step! = dummy_step!)
        add_random_agents!(model)
        fig, _ = abmplot(model)
        @test true
    end

    @testset "OpenStreetMapSpace" begin
        osm = OSM.test_map()
        model = StandardABM(OSMAgent, OpenStreetMapSpace(osm); agent_step! = dummy_step!)
        add_random_agents!(model)
        fig, _ = abmplot(model)
        @test true
    end

end
