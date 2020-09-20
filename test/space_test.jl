@testset "Space" begin

@testset "1D grids" begin
    a = GridSpace((5, ))
    @test size(a) == (5, )
    @test typeof(a.s) <: Array{Array{Int64,1},1}
    @test a.metric == :chebyshev

    b = GridSpace((5, ), periodic = false)
    @test size(b) == (5, )
    @test typeof(b.s) <: Array{Array{Int64,1},1}
    @test b.metric == :chebyshev

    c = GridSpace((3, ), metric = :euclidean)
    @test size(c) == (3, )
    @test typeof(c.s) <: Array{Array{Int64,1},1}
    @test c.metric == :euclidean

    d = GridSpace((3, ), metric = :euclidean, periodic = false)
    @test size(d) == (3, )
    @test typeof(d.s) <: Array{Array{Int64,1},1}
    @test d.metric == :euclidean
end

@testset "2D grids" begin
    a = GridSpace((2, 3))
    @test size(a) == (2, 3)
    @test typeof(a.s) <: Array{Array{Int64,1},2}
    @test a.metric == :chebyshev

    b = GridSpace((2, 3), periodic = false)
    @test size(b) == (2, 3)
    @test typeof(b.s) <: Array{Array{Int64,1},2}
    @test b.metric == :chebyshev

    c = GridSpace((3, 3), metric = :euclidean)
    @test size(c) == (3, 3)
    @test typeof(c.s) <: Array{Array{Int64,1},2}
    @test c.metric == :euclidean

    d = GridSpace((3, 4), metric = :euclidean, periodic = false)
    @test size(d) == (3, 4)
    @test typeof(d.s) <: Array{Array{Int64,1},2}
    @test d.metric == :euclidean
end

@testset "3D grid" begin
    a = GridSpace((2, 3, 4))
    @test size(a) == (2, 3, 4)
    @test typeof(a.s) <: Array{Array{Int64,1},3}
    @test a.metric == :chebyshev

    b = GridSpace((2, 3, 7), periodic = false)
    @test size(b) == (2, 3, 7)
    @test typeof(b.s) <: Array{Array{Int64,1},3}
    @test b.metric == :chebyshev

    c = GridSpace((3, 3, 3), metric = :euclidean)
    @test size(c) == (3, 3, 3)
    @test typeof(c.s) <: Array{Array{Int64,1},3}
    @test c.metric == :euclidean

    d = GridSpace((3, 4, 2), metric = :euclidean, periodic = false)
    @test size(d) == (3, 4, 2)
    @test typeof(d.s) <: Array{Array{Int64,1},3}
    @test d.metric == :euclidean
end

@testset "Positions" begin
    space = GridSpace((3, 3))
    model = ABM(Agent1, space)
    empty = empty_positions(model)
    @test length(empty) > 0
    for n in [1, 5, 6, 9, 2, 3, 4]
        add_agent!(empty[n], model)
    end
    # only positions (1,3) and (2,3) should be empty
    @test random_empty(model) ∈ [(1,3), (2,3)]
    pos_map = [(1, 1)  (1, 2)  (1, 3)
               (2, 1)  (2, 2)  (2, 3)
               (3, 1)  (3, 2)  (3, 3)]
    @test collect(positions(model)) == pos_map
    random_positions = positions(model, :random)
    @test all(n ∈ pos_map for n in random_positions)
    @test positions(model, :population) == [pos_map[i] for i in [1, 2, 3, 4, 5, 6, 9, 7, 8]]
    @test length(agents_in_pos(5, model)) > length(agents_in_pos(7, model))
    @test_throws ErrorException positions(model, :notreal)
end

@testset "Neighbors" begin
    undirected = ABM(Agent5, GraphSpace(path_graph(5)))
    @test nearby_positions(3, undirected) == [2, 4]
    @test nearby_positions(1, undirected) == [2]
    @test nearby_positions(5, undirected) == [4]
    @test nearby_positions(3, undirected; neighbor_type = :out) ==
    nearby_positions(3, undirected; neighbor_type = :in) ==
    nearby_positions(3, undirected; neighbor_type = :all) ==
    nearby_positions(3, undirected; neighbor_type = :default)
    add_agent!(1, undirected, rand())
    add_agent!(2, undirected, rand())
    add_agent!(3, undirected, rand())
    # We expect id 2 to be included for a grid based search
    @test sort!(collect(nearby_agents(2, undirected))) == [1, 2, 3]
    # But to be excluded if we are looking around it.
    @test sort!(collect(nearby_agents(undirected[2], undirected))) == [1, 3]

    directed = ABM(Agent5, GraphSpace(path_digraph(5)))
    @test nearby_positions(3, directed) == [4]
    @test nearby_positions(1, directed) == [2]
    @test nearby_positions(5, directed) == []
    @test nearby_positions(3, directed; neighbor_type = :default) ==
          nearby_positions(3, directed)
    @test nearby_positions(3, directed; neighbor_type = :in) == [2]
    @test nearby_positions(3, directed; neighbor_type = :out) == [4]
    @test sort!(nearby_positions(3, directed; neighbor_type = :all)) == [2, 4]
    add_agent!(1, directed, rand())
    add_agent!(2, directed, rand())
    add_agent!(3, directed, rand())
    @test sort!(nearby_agents(2, directed)) == [2, 3]
    @test sort!(nearby_agents(2, directed; neighbor_type=:in)) == [1, 2]
    @test sort!(nearby_agents(2, directed; neighbor_type=:all)) == [1, 2, 3]
    @test collect(nearby_agents(directed[2], directed)) == [3]
    @test collect(nearby_agents(directed[2], directed; neighbor_type=:in)) == [1]
    @test sort!(collect(nearby_agents(directed[2], directed; neighbor_type=:all))) == [1, 3]

    gridspace = ABM(Agent3, GridSpace((3, 3); metric = :euclidean, periodic = false))
    @test collect(nearby_positions((2, 2), gridspace)) == [(2, 1), (1, 2), (3, 2), (2, 3)]
    @test collect(nearby_positions((1, 1), gridspace)) == [(2, 1), (1, 2)]
    a = add_agent!((2, 2), gridspace, rand())
    add_agent!((3, 2), gridspace, rand())
    @test collect(nearby_agents((1, 2), gridspace)) == [1]
    @test sort!(collect(nearby_agents((1, 2), gridspace, 2))) == [1, 2]
    @test sort!(collect(nearby_agents((2, 2), gridspace))) == [1, 2]
    @test collect(nearby_agents(a, gridspace)) == [2]

    continuousspace = ABM(Agent6, ContinuousSpace(2; extend = (1, 1)))
    a = add_agent!((0.5, 0.5), continuousspace, (0.2, 0.1), 0.01)
    b = add_agent!((0.6, 0.5), continuousspace, (0.1, -0.1), 0.01)
    @test_throws ErrorException nearby_positions(1, continuousspace)
    @test nearby_agents(a, continuousspace, 0.05) == []
    @test nearby_agents(a, continuousspace, 0.1) == [2]
    @test sort!(nearby_agents((0.55, 0.5), continuousspace, 0.05)) == [1, 2]
    move_agent!(a, continuousspace)
    move_agent!(b, continuousspace)
    @test nearby_agents(a, continuousspace, 0.1) == []
    # Checks for type instability #208
    @test typeof(nearby_agents(a, continuousspace, 0.1)) <: Vector{Int}
    @test typeof(nearby_agents((0.55, 0.5), continuousspace, 0.05)) <: Vector{Int}
end

@testset "Discrete space mutability" begin
    model1 = ABM(Agent1, GridSpace((3,3)))

    agent = add_agent!((1,1), model1)
    @test agent.pos == (1, 1)
    @test agent.id == 1
    pos1 = agents_in_pos((1,1), model1)
    @test length(pos1) == 1
    @test pos1[1] == 1

    move_agent!(agent, (2,2), model1)
    @test agent.pos == (2,2)
    pos1 = agents_in_pos((1,1), model1)
    @test length(pos1) == 0
    pos2 = agents_in_pos((2,2), model1)
    @test pos2[1] == 1

    # %% get/set testing
    model = ABM(Agent1, GridSpace((10,10)); properties=Dict(:number => 1, :nested => BadAgent(1,1)))
    add_agent!(model)
    add_agent!(model)
    @test (model.number += 1) == 2
    @test (model.nested.pos = 5) == 5
    @test_throws ErrorException (model.space = ContinuousSpace(2))
end

end
