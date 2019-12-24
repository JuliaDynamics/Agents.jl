using Random
Random.seed!(209)

@testset "0D grids" begin
  @test Space((1,)).graph == Agents.Graph(1)
end

@testset "1D grids" begin
  a = Space((5,1))
  ae = collect(Agents.LightGraphs.edges(a.graph))

  b = Space((5,1), periodic=true)
  be = collect(Agents.LightGraphs.edges(b.graph))

  @test ae == [Agents.LightGraphs.Edge(1,2),Agents.LightGraphs.Edge(2,3), Agents.LightGraphs.Edge(3,4), Agents.LightGraphs.Edge(4,5)]
  @test be == [Agents.LightGraphs.Edge(1,2), Agents.LightGraphs.Edge(1,5), Agents.LightGraphs.Edge(2,3), Agents.LightGraphs.Edge(3,4), Agents.LightGraphs.Edge(4,5)]
end

@testset "2D grids" begin
  @test Space((2,1)).graph == Agents.Graph(2,1)
  
  a = Space((2,3))
  b = Space((2,3), periodic=true) # 2D grid

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
  a = Space((3, 3), moore=true)
  @test Agents.nv(a) == 9
  @test Agents.ne(a) == 20

  a = Space((3, 4), moore=true)
  @test Agents.nv(a) == 12
  @test Agents.ne(a) == 29

  b = Space((3, 2), moore=true, periodic=true)
  @test Agents.nv(b) == 6
  @test Agents.ne(b) == 15

  b = Space((3, 3), moore=true, periodic=true)
  @test Agents.nv(b) == 9
  @test Agents.ne(b) == 36
end

@testset "3D grid" begin
  g1 = Space((2,3,2))
  g2 = Space((2,3,3))
  g3 = Space((2,3,2), periodic=true)
  g4 = Space((2,3,3), periodic=true)
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

mutable struct Agent1 <: AbstractAgent
  id::Int 
  pos::Tuple{Int,Int}
end

mutable struct Agent2 <: AbstractAgent
  id::Int 
  pos::Tuple{Int,Int}
  p::Int
end

@testset "Agent-Space interactions" begin

  model = model_initiation(f=0.1, d=0.8, p=0.1, griddims=(20, 20), seed=2)  # forest fire model

  agent = model.agents[1]
  move_agent!(agent, (3,4), model)  # node number 63
  @test agent.pos == (3,4)
  @test agent.id in model.space.agent_positions[63]

  agent = model.agents[2]
  move_agent!(agent, 83, model)  # pos (3,5)
  @test agent.pos == (3,5)
  @test agent.id in model.space.agent_positions[83]
  
  new_pos = move_agent!(agent, model)
  @test agent.id in model.space.agent_positions[coord2vertex(new_pos, model)]

  add_agent!(agent, (2,9), model)
  @test agent.pos == (2,9)
  @test agent.id in model.space.agent_positions[coord2vertex((2,9), model)]
  @test agent.id in model.space.agent_positions[coord2vertex(new_pos, model)]

  model1 = ABM(Agent1, Space((3,3)))
  add_agent!(1, model1)
  @test model1.agents[1].pos == (1, 1)
  add_agent!((2,1), model1)
  @test model1.agents[2].pos == (2, 1)
  
  model2 = ABM(Agent2, Space((3,3)))
  add_agent!(1, model2, 3)
  @test model2.agents[1].pos == (1,1)
  @test 1 in model2.space.agent_positions[1]
  add_agent!((2,1), model2, 2)
  @test model2.agents[2].pos == (2,1)
  @test 2 in model2.space.agent_positions[2]
  ag = add_agent!(model2, 12)
  @test ag.id in model2.space.agent_positions[coord2vertex(ag.pos, model2)]

  
  @test agent.id in get_node_contents(agent, model)

  ii = model.agents[length(model.agents)]
  @test id2agent(ii.id, model) == model.agents[ii.id]

  agent = model.agents[1]
  agent_pos = coord2vertex(agent.pos, model)
  kill_agent!(agent, model)
  @test_throws KeyError id2agent(1, model) 
  @test !in(1, Agents.agent_positions(model)[agent_pos])
end

@testset "nodes" begin
  space = Space((3,3))
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
