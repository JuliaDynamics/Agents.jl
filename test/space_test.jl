using Random
Random.seed!(209)

@testset "Deprecated spaces" begin
  # GraphSpace
  @test_deprecated (@test_throws TypeError Space(Agents.Graph(1)))
  # GridSpace
  @test_deprecated (@test_throws TypeError Space((5,1)))
  # ContinuousSpace
  @test_deprecated Space(5, (a,m)->nothing)
end

@testset "graphs" begin
  @test GraphSpace(Agents.Graph(1)).graph == Agents.Graph(1) #TODO: poor test
end

@testset "0D grids" begin
  @test GridSpace((1,)).graph == Agents.Graph(1)
end

@testset "1D grids" begin
  a = GridSpace((5,1))
  ae = collect(Agents.LightGraphs.edges(a.graph))

  b = GridSpace((5,1), periodic=true)
  be = collect(Agents.LightGraphs.edges(b.graph))

  @test ae == [Agents.LightGraphs.Edge(1,2),Agents.LightGraphs.Edge(2,3), Agents.LightGraphs.Edge(3,4), Agents.LightGraphs.Edge(4,5)]
  @test be == [Agents.LightGraphs.Edge(1,2), Agents.LightGraphs.Edge(1,5), Agents.LightGraphs.Edge(2,3), Agents.LightGraphs.Edge(3,4), Agents.LightGraphs.Edge(4,5)]
end

@testset "2D grids" begin
  @test GridSpace((2,1)).graph == Agents.Graph(2,1)

  a = GridSpace((2,3))
  b = GridSpace((2,3), periodic=true) # 2D grid

  @test a.dimensions == (2,3)
  @test b.dimensions == (2,3)
  @test length(a.agent_positions) == 6
  @test length(b.agent_positions) == 6

  @test Agents.nv(a) == 6
  @test Agents.ne(a) == 7
  @test Agents.nv(b) == 6
  @test Agents.ne(b) == 9

  ae = collect(Agents.LightGraphs.edges(a.graph))
  be = collect(Agents.LightGraphs.edges(b.graph))

  @test ae == [Agents.LightGraphs.Edge(1,2), Agents.LightGraphs.Edge(1,3), Agents.LightGraphs.Edge(2,4), Agents.LightGraphs.Edge(3,4), Agents.LightGraphs.Edge(3,5), Agents.LightGraphs.Edge(4,6), Agents.LightGraphs.Edge(5,6)]
  @test be == [Agents.LightGraphs.Edge(1,2), Agents.LightGraphs.Edge(1,3), Agents.LightGraphs.Edge(1,5), Agents.LightGraphs.Edge(2,4), Agents.LightGraphs.Edge(2,6), Agents.LightGraphs.Edge(3,4), Agents.LightGraphs.Edge(3,5), Agents.LightGraphs.Edge(4,6), Agents.LightGraphs.Edge(5,6)]
end

@testset "2D Moore" begin
  a = GridSpace((3, 3), moore=true)
  @test Agents.nv(a) == 9
  @test Agents.ne(a) == 20

  a = GridSpace((3, 4), moore=true)
  @test Agents.nv(a) == 12
  @test Agents.ne(a) == 29

  b = GridSpace((3, 2), moore=true, periodic=true)
  @test Agents.nv(b) == 6
  @test Agents.ne(b) == 15

  b = GridSpace((3, 3), moore=true, periodic=true)
  @test Agents.nv(b) == 9
  @test Agents.ne(b) == 36
end

@testset "3D grid" begin
  g1 = GridSpace((2,3,2))
  g2 = GridSpace((2,3,3))
  g3 = GridSpace((2,3,2), periodic=true)
  g4 = GridSpace((2,3,3), periodic=true)
  @test Agents.ne(g1) == 20
  @test Agents.ne(g2) == 33
  @test Agents.ne(g3) == 24
  @test Agents.ne(g4) == 39
end

@testset "grid coord/vertex conversions" begin
  @test coord2vertex((2,2,1), (3,4,1)) == 5
  @test coord2vertex((2,2), (3,4)) == 5
  @test coord2vertex((2,2,1), (3,4,1)) == 5
  @test coord2vertex((2,2), (3,4)) == 5
  @test vertex2coord(5, (3,4,1)) == (2,2,1)
  @test vertex2coord(5, (3,4)) == (2,2)

  @test coord2vertex((2,2,1), (2,3,3)) == 4
  @test coord2vertex((2,2,2), (2,3,3)) == 10
  @test coord2vertex((2,2,3), (2,3,3)) == 16
  @test coord2vertex(((1,3,1)), (2,3,3)) == 5
  @test coord2vertex((1,3,2), (2,3,3)) == 11
  @test coord2vertex((1,3,3), (2,3,3)) == 17

  @test vertex2coord(5, (2,3,3)) == (1,3,1)
  @test vertex2coord(7, (2,3,3)) == (1,1,2)
  @test vertex2coord(13, (2,3,3)) == (1,1,3)
  @test vertex2coord(13, (2,3,3)) == (1,1,3)
  @test vertex2coord(15, (2,3,3)) == (1,2,3)
  @test vertex2coord(18, (2,3,3)) == (2,3,3)
  @test vertex2coord(18, (2,3,3)) == (2,3,3)
end

@testset "nodes" begin
  space = GridSpace((3,3))
  model = ABM(Agent1, space)
  for node in nodes(model)
    if rand() > 0.7
      add_agent!(node, model)
    end
  end
  @test nodes(model) == 1:9
  @test nodes(model, by=:random) == [8, 9, 1, 7, 6, 5, 3, 2, 4]
  @test nodes(model, by=:population) == [4, 5, 8, 9, 1, 2, 3, 6, 7]
  @test length(get_node_contents(4, model)) > length(get_node_contents(7, model))
  @test_throws ErrorException nodes(model, by=:notreal)
end
