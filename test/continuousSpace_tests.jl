
@testset "Continuous space" begin
  space1 = Space(2; periodic = true, extend = (1, 1))
  space2 = Space(2; periodic = false, extend = (1, 1))
  space3 = Space(2; periodic = true, extend = (2, 1))
  space4 = Space(2; periodic = true, extend = (1, 2))
  space5 = Space(2; periodic = true, extend = (2, 2))
  space6 = Space(1; periodic = true, extend = (1,))
  space7 = Space(3; periodic = true, extend = (1,1,1))
  space8 = Space(3; periodic = false, extend = (1,1,1))

  @test space1.D == 2
  @test space2.D == 2
  @test space3.D == 2
  @test space4.D == 2
  @test space5.D == 2
  @test space6.D == 1
  @test space7.D == 3
  @test space8.D == 3

  model1 = ABM(Agent6, space1)

  @test nagents(model1) == 0
  @test Agents.collect_ids(DBInterface.execute(model1.space.db, "select id from tab")) == []

  pos = (0.5, 0.5)
  vel = sincos(2π*rand()) .* 0.05
  dia = 0.01
  add_agent!(pos, model1, vel, dia)
  @test Agents.collect_ids(DBInterface.execute(model1.space.db, "select id from tab")) == [1]
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame;
  @test dbrow[1, :a] == 0.5
  @test dbrow[1, :b] == 0.5
  
  move_agent!(model1.agents[1], model1)
  @test model1.agents[1].pos[1] != 0.5
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame;
  @test dbrow[1, :a] != 0.5
  @test dbrow[1, :b] != 0.5
  @test dbrow[1, :a] == model1.agents[1].pos[1]
  @test dbrow[1, :b] == model1.agents[1].pos[2]

  kill_agent!(model1.agents[1], model1)
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame
  @test size(dbrow) == (0,0)

  agent = Agent6(2, pos, vel, dia)
  add_agent!(agent, model1)
  @test Agents.collect_ids(DBInterface.execute(model1.space.db, "select id from tab")) == [2]
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame;
  @test dbrow[1, :a] == 0.5
  @test dbrow[1, :b] == 0.5
end
