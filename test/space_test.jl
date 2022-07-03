# TODO: This test file needs a complete re-write...

@testset "Space" begin
    @testset "Graphs" begin
        model = ABM(Agent5, GraphSpace(path_graph(5)))
        @test Agents.nv(model) == 5
        @test Agents.ne(model) == 4
    end

    @testset "Euclidean Distance" begin
        model = ABM(Agent6, ContinuousSpace((12, 10), 0.2; periodic = true))
        a = add_agent!((1.0, 6.0), model, (0.5, 0.5), 2.0)
        b = add_agent!((11.0, 4.0), model, (0.5, 0.7), 3.0)
        @test euclidean_distance(a, b, model) ≈ 2.82842712

        model = ABM(Agent6, ContinuousSpace((12, 10), 0.2; periodic = false))
        a = add_agent!((1.0, 6.0), model, (0.5, 0.5), 2.0)
        b = add_agent!((11.0, 4.0), model, (0.5, 0.7), 3.0)
        @test euclidean_distance(a, b, model) ≈ 10.198039

    end

    @testset "Nearby Agents" begin
        undirected = ABM(Agent5, GraphSpace(path_graph(5)))
        @test nearby_positions(3, undirected) == [2, 4]
        @test nearby_positions(1, undirected) == [2]
        @test nearby_positions(5, undirected) == [4]
        @test sort!(nearby_positions(5, undirected, 2)) == [3, 4]
        @test sort!(nearby_positions(3, undirected, 2)) == [1, 2, 4, 5]
        @test nearby_positions(3, undirected; neighbor_type = :out) ==
              nearby_positions(3, undirected; neighbor_type = :in) ==
              nearby_positions(3, undirected; neighbor_type = :all) ==
              nearby_positions(3, undirected; neighbor_type = :default)
        add_agent!(1, undirected, rand(undirected.rng))
        agent = add_agent!(2, undirected, rand(undirected.rng))
        add_agent!(3, undirected, rand(undirected.rng))
        @test sort!(nearby_positions(agent, undirected)) == [1, 3]
        # We expect id 2 to be included for a grid based search
        @test sort!(collect(nearby_ids(2, undirected))) == [1, 2, 3]
        # But to be excluded if we are looking around it.
        @test sort!(collect(nearby_ids(undirected[2], undirected))) == [1, 3]

        directed = ABM(Agent5, GraphSpace(path_digraph(5)))
        @test nearby_positions(3, directed) == [4]
        @test nearby_positions(1, directed) == [2]
        @test nearby_positions(5, directed) == []
        @test nearby_positions(3, directed; neighbor_type = :default) ==
              nearby_positions(3, directed)
        @test nearby_positions(3, directed; neighbor_type = :in) == [2]
        @test nearby_positions(3, directed; neighbor_type = :out) == [4]
        @test sort!(nearby_positions(3, directed; neighbor_type = :all)) == [2, 4]
        add_agent!(1, directed, rand(directed.rng))
        add_agent!(2, directed, rand(directed.rng))
        add_agent!(3, directed, rand(directed.rng))
        @test sort!(nearby_ids(2, directed)) == [2, 3]
        @test sort!(nearby_ids(2, directed; neighbor_type = :in)) == [1, 2]
        @test sort!(nearby_ids(2, directed; neighbor_type = :all)) == [1, 2, 3]
        @test collect(nearby_ids(directed[2], directed)) == [3]
        @test collect(nearby_ids(directed[2], directed; neighbor_type = :in)) == [1]
        @test sort!(collect(nearby_ids(directed[2], directed; neighbor_type = :all))) ==
              [1, 3]




###################################################################################
# Continuous space

        extent = (1.0, 1.0)
        continuousspace = ABM(Agent6, ContinuousSpace(extent; spacing = 0.1); rng = StableRNG(78))
        a = add_agent!((0.5, 0.5), continuousspace, (0.2, 0.1), 0.01)
        b = add_agent!((0.6, 0.5), continuousspace, (0.1, -0.1), 0.01)
        @test nagents(continuousspace) == 2
        @test_throws ErrorException nearby_positions(1, continuousspace)

        # Nearby stuff
        @test collect(nearby_ids(a, continuousspace, 0.05)) == [2] # Not true, but we are not using the exact method
        @test collect(nearby_ids(a, continuousspace, 0.05; exact = true)) == []
        @test collect(nearby_ids(a, continuousspace, 0.1)) == [2]
        @test sort!(collect(nearby_ids((0.55, 0.5), continuousspace, 0.05))) == [1, 2]

        # Move agent using velocity
        move_agent!(a, continuousspace, 1)
        move_agent!(b, continuousspace, 1)
        @test collect(nearby_ids(a, continuousspace, 0.1; exact = true)) == []
        # Checks for type instability #208
        @test typeof(collect(nearby_ids(a, continuousspace, 0.1))) <: Vector{Int}
        @test typeof(collect(nearby_ids((0.55, 0.5), continuousspace, 0.05))) <: Vector{Int}

        # move agent using random position
        # TODO:

    end

    mutable struct Agent3D <: AbstractAgent
        id::Int
        pos::Dims{3}
        weight::Float64
    end

    mutable struct Agent63 <: AbstractAgent
        id::Int
        pos::NTuple{3,Float64}
        vel::NTuple{3,Float64}
        weight::Float64
    end

    @testset "Walk" begin
        # ContinuousSpace
        model = ABM(Agent6, ContinuousSpace((12, 10), 0.2; periodic = false))
        a = add_agent!((0.0, 0.0), model, (0.0, 0.0), rand(model.rng))
        walk!(a, (1.0, 1.0), model)
        @test a.pos == (1.0, 1.0)
        walk!(a, (15.0, 1.0), model)
        @test a.pos == (12.0 - 1e-15, 2.0)

        model = ABM(Agent63, ContinuousSpace((12, 10, 5), 0.2))
        a = add_agent!((0.0, 0.0, 0.0), model, (0.0, 0.0, 0.0), rand(model.rng))
        walk!(a, (1.0, 1.0, 1.0), model)
        @test a.pos == (1.0, 1.0, 1.0)
        walk!(a, (15.0, 1.2, 3.9), model)
        @test a.pos == (4.0, 2.2, 4.9)

        @test_throws MethodError walk!(a, (1, 1, 5), model) # Must use Float64 for continuousspace

        rng0 = StableRNG(42)
        model = ABM(Agent6, ContinuousSpace((12, 10), 0.2); rng = rng0)
        a = add_agent!((7.2, 3.9), model, (0.0, 0.0), rand(model.rng))
        walk!(a, rand, model)
        @test a.pos[1] ≈ 6.5824829589163665
        @test a.pos[2] ≈ 4.842266936412905
    end
end
