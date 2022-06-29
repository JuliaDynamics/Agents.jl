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
# Grid space


###################################################################################
# Continuous space

        Random.seed!(78)
        continuousspace = ABM(Agent6, ContinuousSpace((1, 1), 0.1))
        a = add_agent!((0.5, 0.5), continuousspace, (0.2, 0.1), 0.01)
        b = add_agent!((0.6, 0.5), continuousspace, (0.1, -0.1), 0.01)
        @test_throws MethodError nearby_positions(1, continuousspace)
        @test collect(nearby_ids(a, continuousspace, 0.05)) == [2] # Not true, but we are not using the exact method
        @test collect(nearby_ids(a, continuousspace, 0.05; exact = true)) == []
        @test collect(nearby_ids(a, continuousspace, 0.1)) == [2]
        @test sort!(collect(nearby_ids((0.55, 0.5), continuousspace, 0.05))) == [1, 2]
        move_agent!(a, continuousspace)
        move_agent!(b, continuousspace)
        @test collect(nearby_ids(a, continuousspace, 0.1; exact = true)) == []
        # Checks for type instability #208
        @test typeof(collect(nearby_ids(a, continuousspace, 0.1))) <: Vector{Int}
        @test typeof(collect(nearby_ids((0.55, 0.5), continuousspace, 0.05))) <: Vector{Int}

        # Test random_nearby_*
        abm = ABM(Agent1, GridSpace((10, 10)); rng = MersenneTwister(42))
        for i in 1:10, j in 1:10
            add_agent!((i, j), abm)
        end

        nearby_id = random_nearby_id(abm[1], abm, 5)
        valid_ids = collect(nearby_ids(abm[1], abm, 5))
        @test nearby_id in valid_ids
        nearby_agent = random_nearby_agent(abm[1], abm, 5)
        @test nearby_agent.id in valid_ids

        genocide!(abm)
        a = add_agent!((1, 1), abm)
        @test isnothing(random_nearby_id(a, abm))
        @test isnothing(random_nearby_agent(a, abm))
        add_agent!((1,2), abm)
        add_agent!((2,1), abm)
        rand_nearby_ids = Set([random_nearby_id(a, abm, 2) for _ in 1:100])
        @test length(rand_nearby_ids) == 2
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
        # Periodic
        model = ABM(Agent3, GridSpace((3, 3)))
        a = add_agent!((1, 1), model, rand(model.rng))
        walk!(a, (0, 1), model) # North
        @test a.pos == (1, 2)
        walk!(a, (1, 1), model) # North east
        @test a.pos == (2, 3)
        walk!(a, (1, 0), model) # East
        @test a.pos == (3, 3)
        walk!(a, (2, 0), model) # PBC, East two steps
        @test a.pos == (2, 3)
        walk!(a, (1, -1), model) # South east
        @test a.pos == (3, 2)
        walk!(a, (0, -1), model) # South
        @test a.pos == (3, 1)
        walk!(a, (-1, -1), model) # PBC, South west
        @test a.pos == (2, 3)
        walk!(a, (-1, 0), model) # West
        @test a.pos == (1, 3)
        walk!(a, (0, -8), model) # Round the world, South eight steps
        @test a.pos == (1, 1)

        model = ABM(Agent3, GridSpace((3, 3)))
        a = add_agent!((1, 1), model, rand(model.rng))
        add_agent!((2, 2), model, rand(model.rng))
        walk!(a, (1, 1), model; ifempty = true)
        @test a.pos == (1, 1)
        walk!(a, (1, 0), model; ifempty = true)
        @test a.pos == (2, 1)

        model = ABM(Agent3, GridSpace((3, 3); periodic = false))
        a = add_agent!((1, 1), model, rand(model.rng))
        walk!(a, (0, 1), model) # North
        @test a.pos == (1, 2)
        walk!(a, (1, 1), model) # North east
        @test a.pos == (2, 3)
        walk!(a, (1, 0), model) # East
        @test a.pos == (3, 3)
        walk!(a, (1, 0), model) # Boundary, attempt East
        @test a.pos == (3, 3)
        walk!(a, (-5, 0), model) # Boundary, attempt West five steps
        @test a.pos == (1, 3)
        walk!(a, (-1, -1), model) # Boundary in one direction, not in the other, attempt South west
        @test a.pos == (1, 2)

        @test_throws MethodError walk!(a, (1.0, 1.5), model) # Must use Int for gridspace

        # Higher dimensions also possible and behave the same.
        model = ABM(Agent3D, GridSpace((3, 3, 2)))
        a = add_agent!((1, 1, 1), model, rand(model.rng))
        walk!(a, (1, 1, 1), model)
        @test a.pos == (2, 2, 2)
        walk!(a, (-1, 1, 1), model)
        @test a.pos == (1, 3, 1)

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

        # Random Walks
        model = ABM(Agent3, GridSpace((5, 5)); rng = StableRNG(65))
        a = add_agent!((3, 3), model, rand(model.rng))
        walk!(a, rand, model)
        @test a.pos == (2, 4)
        walk!(a, rand, model)
        @test a.pos == (1, 3)
        walk!(a, rand, model)
        @test a.pos == (5, 4)

        rng0 = StableRNG(42)
        model = ABM(Agent6, ContinuousSpace((12, 10), 0.2); rng = rng0)
        a = add_agent!((7.2, 3.9), model, (0.0, 0.0), rand(model.rng))
        walk!(a, rand, model)
        @test a.pos[1] ≈ 6.5824829589163665
        @test a.pos[2] ≈ 4.842266936412905
    end
end
