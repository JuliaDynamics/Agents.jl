
@testset "0D grid" begin
  @test Agents.grid0D() == Agents.Graph(1)
end

Random.seed!(209)

@testset "1D grid" begin
  obj1 = Agents.grid1D(5)
  obj2 = Agents.grid1D(5, periodic=true)
  @test Agents.nv(obj1) == 5
  @test Agents.nv(obj2) == 5
  @test Agents.ne(obj1) == 4
  @test Agents.ne(obj2) == 5
  last_edge1 = collect(Agents.edges(obj1))[end]
  last_edge2 = collect(Agents.edges(obj2))[2]
  @test last_edge1.src == 4
  @test last_edge1.dst == 5
  @test last_edge2.src == 1
  @test last_edge2.dst == 5
end

@testset "2D grid" begin
  obj1 = Agents.grid2D(3, 4)
  obj2 = Agents.grid2D(3, 4, periodic=true)
  @test Agents.nv(obj1) == 12
  @test Agents.nv(obj2) == 12
  @test Agents.ne(obj1) == 17
  @test Agents.ne(obj2) == 24
end

@testset "2D Moore" begin
  obj1 = Agents.grid2D_Moore(3, 3)
  @test Agents.nv(obj1) == 9
  @test Agents.ne(obj1) == 20
  obj1 = Agents.grid2D_Moore(3, 4)
  @test Agents.nv(obj1) == 12
  @test Agents.ne(obj1) == 29
  obj2 = Agents.grid2D_Moore(3, 2, periodic=true)
  @test Agents.nv(obj2) == 6
  @test Agents.ne(obj2) == 15
  obj2 = Agents.grid2D_Moore(3, 3, periodic=true)
  @test Agents.nv(obj2) == 9
  @test Agents.ne(obj2) == 36
end

@testset "3D grid" begin
  g1 = Agents.grid3D(2,3,2)
  g2 = Agents.grid3D(2,3,3)
  g3 = Agents.grid3D(2,3,2, periodic=true)
  g4 = Agents.grid3D(2,3,3, periodic=true)
  @test Agents.ne(g1) == 20
  @test Agents.ne(g2) == 33
  @test Agents.ne(g3) == 24
  @test Agents.ne(g4) == 39
end

@testset "grid coord/vertex conversions" begin
  @test coord_to_vertex((2,2,1), (3,4,1)) == 5
  @test coord_to_vertex((2,2), (3,4)) == 5
  @test coord_to_vertex(2,2,1, (3,4,1)) == 5
  @test coord_to_vertex(2,2, (3,4)) == 5
  @test vertex_to_coord(5, (3,4,1)) == (2,2,1)
  @test vertex_to_coord(5, (3,4)) == (2,2)

  @test coord_to_vertex((2,2,1), (2,3,3)) == 4
  @test coord_to_vertex((2,2,2), (2,3,3)) == 10
  @test coord_to_vertex((2,2,3), (2,3,3)) == 16
  @test coord_to_vertex((1,3,1), (2,3,3)) == 5
  @test coord_to_vertex((1,3,2), (2,3,3)) == 11
  @test coord_to_vertex((1,3,3), (2,3,3)) == 17
  
  @test vertex_to_coord(5, (2,3,3)) == (1,3,1)
  @test vertex_to_coord(7, (2,3,3)) == (1,1,2)
  @test vertex_to_coord(13, (2,3,3)) == (1,1,3)
  @test vertex_to_coord(13, (2,3,3)) == (1,1,3)
  @test vertex_to_coord(15, (2,3,3)) == (1,2,3)
  @test vertex_to_coord(18, (2,3,3)) == (2,3,3)
  @test vertex_to_coord(18, (2,3,3)) == (2,3,3)
end

@testset "grid" begin
  @test Agents.grid(1,1,1, false, true) == Agents.grid0D()
  @test Agents.grid(1,1,1, true, true) == Agents.grid0D()
  @test Agents.grid(6,1,1, true, true) == Agents.grid1D(6, periodic=true)
  @test Agents.grid(6,1,1, false, true) == Agents.grid1D(6, periodic=false)
  @test Agents.grid(6,5,1, false, true) == Agents.grid2D_Moore(6, 5, periodic=false)
  @test Agents.grid(6,5, false, true) == Agents.grid2D_Moore(6, 5, periodic=false)
  @test Agents.grid(6,5,1, true, true) == Agents.grid2D_Moore(6, 5, periodic=true)
  @test Agents.grid(6,5, true, true) == Agents.grid2D_Moore(6, 5, periodic=true)
  @test Agents.grid(6,5,1, true, false) == Agents.grid2D(6, 5, periodic=true)
  @test Agents.grid(6,5, true, false) == Agents.grid2D(6, 5, periodic=true)
  @test Agents.grid(6,5,1, false, false) == Agents.grid2D(6, 5, periodic=false)
  @test Agents.grid(6,5, false, false) == Agents.grid2D(6, 5, periodic=false)
  @test Agents.grid((3,2,1), false, true) == Agents.grid(3,2,1, false, true) 
  @test Agents.grid((3,2), false, true) == Agents.grid(3,2, false, true) 
end

@testset "gridsize" begin
  @test Agents.gridsize((3,4,6)) == 3*4*6
  @test Agents.gridsize((3,4)) == 12
  @test Agents.gridsize((3,4)) == Agents.gridsize((3,4,1))
end

@testset "all the rest" begin

  model = model_initiation(f=0.1, d=0.8, p=0.1, griddims=(20, 20), seed=2)

  agent = model.agents[1]
  move_agent!(agent, (3,4), model)  # node number 63
  @test agent.pos == (3,4)
  @test agent.id in model.space.agent_positions[63]

  agent = model.agents[2]
  move_agent!(agent, 83, model)  # pos (3,5)
  @test agent.pos == (3,5)
  @test agent.id in model.space.agent_positions[83]
  
  new_pos = move_agent!(agent, model)
  @test agent.id in model.space.agent_positions[coord_to_vertex(new_pos, model)]

  add_agent!(agent, (2,9), model)
  @test agent.pos == (2,9)
  @test agent.id in model.space.agent_positions[coord_to_vertex((2,9), model)]
  @test agent.id in model.space.agent_positions[coord_to_vertex(new_pos, model)]

  @test agent.id in get_node_contents(agent, model)

  ii = model.agents[end].id
  @test id_to_agent(ii, model) == model.agents[end]
end