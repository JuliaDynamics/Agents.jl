Random.seed!(209)

@testset "Deprecated spaces" begin
    # GraphSpace
    @test_deprecated (@test_throws TypeError Space(Agents.Graph(1)))
    # GridSpace
    @test_deprecated (@test_throws TypeError Space((5, 1)))
    # ContinuousSpace
    @test_deprecated Space(5, (a, m) -> nothing)
end


@testset "0D grids" begin
    @test GridSpace((1,)).graph == Agents.Graph(1)
end

@testset "1D grids" begin
    a = GridSpace((5, 1))
    ae = collect(Agents.LightGraphs.edges(a.graph))

    b = GridSpace((5, 1), periodic = true)
    be = collect(Agents.LightGraphs.edges(b.graph))

    @test ae == [
        Agents.LightGraphs.Edge(1, 2),
        Agents.LightGraphs.Edge(2, 3),
        Agents.LightGraphs.Edge(3, 4),
        Agents.LightGraphs.Edge(4, 5),
    ]
    @test be == [
        Agents.LightGraphs.Edge(1, 2),
        Agents.LightGraphs.Edge(1, 5),
        Agents.LightGraphs.Edge(2, 3),
        Agents.LightGraphs.Edge(3, 4),
        Agents.LightGraphs.Edge(4, 5),
    ]
end

@testset "2D grids" begin
    @test GridSpace((2, 1)).graph == Agents.Graph(2, 1)

    a = GridSpace((2, 3))
    b = GridSpace((2, 3), periodic = true) # 2D grid

    @test a.dimensions == (2, 3)
    @test b.dimensions == (2, 3)
    @test length(a.agent_positions) == 6
    @test length(b.agent_positions) == 6

    @test nv(a) == 6
    @test ne(a) == 7
    @test nv(b) == 6
    @test ne(b) == 9

    ae = collect(Agents.LightGraphs.edges(a.graph))
    be = collect(Agents.LightGraphs.edges(b.graph))

    @test ae == [
        Agents.LightGraphs.Edge(1, 2),
        Agents.LightGraphs.Edge(1, 3),
        Agents.LightGraphs.Edge(2, 4),
        Agents.LightGraphs.Edge(3, 4),
        Agents.LightGraphs.Edge(3, 5),
        Agents.LightGraphs.Edge(4, 6),
        Agents.LightGraphs.Edge(5, 6),
    ]
    @test be == [
        Agents.LightGraphs.Edge(1, 2),
        Agents.LightGraphs.Edge(1, 3),
        Agents.LightGraphs.Edge(1, 5),
        Agents.LightGraphs.Edge(2, 4),
        Agents.LightGraphs.Edge(2, 6),
        Agents.LightGraphs.Edge(3, 4),
        Agents.LightGraphs.Edge(3, 5),
        Agents.LightGraphs.Edge(4, 6),
        Agents.LightGraphs.Edge(5, 6),
    ]
end

@testset "2D Moore" begin
    a = GridSpace((3, 3), moore = true)
    @test Agents.nv(a) == 9
    @test Agents.ne(a) == 20

    a = GridSpace((3, 4), moore = true)
    @test Agents.nv(a) == 12
    @test Agents.ne(a) == 29

    b = GridSpace((3, 2), moore = true, periodic = true)
    @test Agents.nv(b) == 6
    @test Agents.ne(b) == 15

    b = GridSpace((3, 3), moore = true, periodic = true)
    @test Agents.nv(b) == 9
    @test Agents.ne(b) == 36
end

@testset "3D grid" begin
    g1 = GridSpace((2, 3, 2))
    g2 = GridSpace((2, 3, 3))
    g3 = GridSpace((2, 3, 2), periodic = true)
    g4 = GridSpace((2, 3, 3), periodic = true)
    @test Agents.ne(g1) == 20
    @test Agents.ne(g2) == 33
    @test Agents.ne(g3) == 24
    @test Agents.ne(g4) == 39
end

@testset "grid coord/vertex conversions" begin
    @test Agents.coord2vertex((2, 2, 1), (3, 4, 1)) == 5
    @test Agents.coord2vertex((2, 2), (3, 4)) == 5
    @test Agents.coord2vertex((2, 2, 1), (3, 4, 1)) == 5
    @test Agents.coord2vertex((2, 2), (3, 4)) == 5
    @test Agents.vertex2coord(5, (3, 4, 1)) == (2, 2, 1)
    @test Agents.vertex2coord(5, (3, 4)) == (2, 2)

    @test Agents.coord2vertex((2, 2, 1), (2, 3, 3)) == 4
    @test Agents.coord2vertex((2, 2, 2), (2, 3, 3)) == 10
    @test Agents.coord2vertex((2, 2, 3), (2, 3, 3)) == 16
    @test Agents.coord2vertex(((1, 3, 1)), (2, 3, 3)) == 5
    @test Agents.coord2vertex((1, 3, 2), (2, 3, 3)) == 11
    @test Agents.coord2vertex((1, 3, 3), (2, 3, 3)) == 17
    @test Agents.coord2vertex((2,), (2, 3, 3)) == 2
    @test Agents.coord2vertex(2, (2, 3, 3)) == 2

    @test Agents.vertex2coord(5, (2, 3, 3)) == (1, 3, 1)
    @test Agents.vertex2coord(7, (2, 3, 3)) == (1, 1, 2)
    @test Agents.vertex2coord(13, (2, 3, 3)) == (1, 1, 3)
    @test Agents.vertex2coord(13, (2, 3, 3)) == (1, 1, 3)
    @test Agents.vertex2coord(15, (2, 3, 3)) == (1, 2, 3)
    @test Agents.vertex2coord(18, (2, 3, 3)) == (2, 3, 3)
    @test Agents.vertex2coord(18, (2, 3, 3)) == (2, 3, 3)

    Random.seed!(648)
    model = ABM(Agent3, GridSpace((5,5)))
    agent = Agent3(1, (1,1), 5.5)
    add_agent!(agent, model)
    @test Agents.coord2vertex(agent, model) == 20
    @test Agents.coord2vertex((1, 3), model) == 11
    @test Agents.coord2vertex(15, model) == 15
    @test Agents.vertex2coord((2,3), model) == (2,3)
    @test_throws MethodError Agents.coord2vertex((1, 3, 7), model) == 11
    @test_throws ErrorException Agents.vertex2coord(3, GraphSpace(complete_digraph(5)))
end

@testset "nodes" begin
    Random.seed!(782)
    space = GridSpace((3, 3))
    model = ABM(Agent1, space)
    @test has_empty_nodes(model)
    for node in nodes(model)
        if rand() > 0.7
            add_agent!(node, model)
        end
    end
    @test pick_empty(model) == 4
    @test nodes(model) == 1:9
    @test nodes(model, by = :random) == [9, 1, 8, 6, 3, 5, 7, 2, 4]
    @test nodes(model, by = :population) == [1, 5, 6, 9, 2, 3, 4, 7, 8]
    @test length(get_node_contents(5, model)) > length(get_node_contents(7, model))
    @test_throws ErrorException nodes(model, by = :notreal)

    iter = NodeIterator(model)
    @test length(iter) == 9
    @test first(NodeIterator(model))[1] == model[1].pos
end

@testset "Neighbors" begin
    undirected = ABM(Agent5, GraphSpace(path_graph(5)))
    @test node_neighbors(3, undirected) == [2, 4]
    @test node_neighbors(1, undirected) == [2]
    @test node_neighbors(5, undirected) == [4]
    @test node_neighbors(3, undirected; neighbor_type = :out) ==
    node_neighbors(3, undirected; neighbor_type = :in) ==
    node_neighbors(3, undirected; neighbor_type = :all) ==
    node_neighbors(3, undirected; neighbor_type = :default)
    add_agent!(1, undirected, rand())
    add_agent!(2, undirected, rand())
    add_agent!(3, undirected, rand())
    # We expect id 2 to be included for a grid based search
    @test sort!(space_neighbors(2, undirected)) == [1, 2, 3]
    # But to be excluded if we are looking around it.
    @test sort!(space_neighbors(undirected[2], undirected)) == [1, 3]

    directed = ABM(Agent5, GraphSpace(path_digraph(5)))
    @test node_neighbors(3, directed) == [4]
    @test node_neighbors(1, directed) == [2]
    @test node_neighbors(5, directed) == []
    @test node_neighbors(3, directed; neighbor_type = :default) ==
          node_neighbors(3, directed)
    @test node_neighbors(3, directed; neighbor_type = :in) == [2]
    @test node_neighbors(3, directed; neighbor_type = :out) == [4]
    @test sort!(node_neighbors(3, directed; neighbor_type = :all)) == [2, 4]
    add_agent!(1, directed, rand())
    add_agent!(2, directed, rand())
    add_agent!(3, directed, rand())
    @test sort!(space_neighbors(2, directed)) == [2, 3]
    @test sort!(space_neighbors(2, directed; neighbor_type=:in)) == [1, 2]
    @test sort!(space_neighbors(2, directed; neighbor_type=:all)) == [1, 2, 3]
    @test space_neighbors(directed[2], directed) == [3]
    @test space_neighbors(directed[2], directed; neighbor_type=:in) == [1]
    @test sort!(space_neighbors(directed[2], directed; neighbor_type=:all)) == [1, 3]

    gridspace = ABM(Agent3, GridSpace((3, 3)))
    @test node_neighbors((2, 2), gridspace) == [(2, 1), (1, 2), (3, 2), (2, 3)]
    @test node_neighbors((1, 1), gridspace) == [(2, 1), (1, 2)]
    a = add_agent!((2, 2), gridspace, rand())
    add_agent!((3, 2), gridspace, rand())
    @test space_neighbors((1, 2), gridspace) == [1]
    @test sort!(space_neighbors((1, 2), gridspace, 2)) == [1, 2]
    @test_throws MethodError space_neighbors((1, 2), gridspace, 1.5)
    @test sort!(space_neighbors((2, 2), gridspace)) == [1, 2]
    @test space_neighbors(a, gridspace) == [2]

    continuousspace = ABM(Agent6, ContinuousSpace(2; extend = (1, 1)))
    a = add_agent!((0.5, 0.5), continuousspace, (0.2, 0.1), 0.01)
    b = add_agent!((0.6, 0.5), continuousspace, (0.1, -0.1), 0.01)
    @test_throws MethodError node_neighbors(1, continuousspace)
    @test space_neighbors(a, continuousspace, 0.05) == []
    @test space_neighbors(a, continuousspace, 0.1) == [2]
    @test sort!(space_neighbors((0.55, 0.5), continuousspace, 0.05)) == [1, 2]
    move_agent!(a, continuousspace)
    move_agent!(b, continuousspace)
    @test space_neighbors(a, continuousspace, 0.1) == []
    # Checks for type instability #208
    @test typeof(space_neighbors(a, continuousspace, 0.1)) <: Vector{Int}
    @test typeof(space_neighbors((0.55, 0.5), continuousspace, 0.05)) <: Vector{Int}
end


