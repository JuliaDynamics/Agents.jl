moore = Agents.moore_neighborhood(2)
vonneumann = Agents.vonneumann_neighborhood(2)
@testset "constructors" begin
    cost = GridSpace((5, 5); pathfinder=(;)).pathfinder.cost_metric
    @test typeof(cost) <: DirectDistance{2}
    @test cost.direction_costs == [10, 14]
    cost = GridSpace((5, 5); pathfinder=(cost_metric = DirectDistance,)).pathfinder.cost_metric
    @test typeof(cost) <: DirectDistance{2}
    @test cost.direction_costs == [10, 14]
    cost = GridSpace((5, 5); pathfinder=(cost_metric = MaxDistance,)).pathfinder.cost_metric
    @test typeof(cost) <: MaxDistance{2}
    @test_throws MethodError AStar((5, 5); cost_metric = HeightMap)
    @test_throws AssertionError AStar((5, 5); cost_metric = HeightMap([1 1]))
    cost = GridSpace((5, 5); pathfinder=(cost_metric = HeightMap(fill(1, 5, 5)),)).pathfinder.cost_metric
    @test typeof(cost) <: HeightMap{2}
    @test typeof(cost.base_metric) <: DirectDistance{2}
    @test cost.hmap == fill(1, 5, 5)
    cost = GridSpace((5, 5); pathfinder=(cost_metric = HeightMap(fill(1, 5, 5), MaxDistance),)).pathfinder.cost_metric
    @test typeof(cost) <: HeightMap{2}
    @test typeof(cost.base_metric) <: MaxDistance{2}
    @test cost.hmap == fill(1, 5, 5)
    hmap = zeros(Int, 1, 1, 1)
    @test_throws MethodError GridSpace((5, 5); pathfinder=(cost_metric = HeightMap(hmap),))

    space = GridSpace((5, 5); pathfinder=(;))
    model = ABM(Agent3, space)
    a = add_agent!((5, 2), model, 654.5)
    @test is_stationary(a, model)
    set_target!(a, (1,3), model)
    @test !is_stationary(a, model)
    @test length(model.space.pathfinder.agent_paths) == 1
    kill_agent!(a, model)
    @test length(model.space.pathfinder.agent_paths) == 0
    @test heightmap(model) === nothing

    hmap = fill(1, 5, 5)
    space = GridSpace((5, 5); pathfinder=(cost_metric = HeightMap(hmap),))
    model = ABM(Agent3, space)
    @test heightmap(model) == hmap
end


@testset "metrics" begin
    pfinder_2d_np_m = AStar{2,false,true}(
        Dict(),
        (10, 10),
        copy(moore),
        0.0,
        fill(true, 10, 10),
        DirectDistance{2}(),
    )
    pfinder_2d_np_nm = AStar{2,false,false}(
        Dict(),
        (10, 10),
        copy(vonneumann),
        0.0,
        fill(true, 10, 10),
        DirectDistance{2}(),
    )
    pfinder_2d_p_m = AStar{2,true,true}(
        Dict(),
        (10, 10),
        copy(moore),
        0.0,
        fill(true, 10, 10),
        DirectDistance{2}(),
    )
    pfinder_2d_p_nm = AStar{2,true,false}(
        Dict(),
        (10, 10),
        copy(vonneumann),
        0.0,
        fill(true, 10, 10),
        DirectDistance{2}(),
    )
    hmap = fill(0, 10, 10)
    hmap[:, 6] .= 100
    hmap[1, 6] = 0

    @test delta_cost(pfinder_2d_np_m, DirectDistance{2}(), (1, 1), (4, 6)) == 62
    @test delta_cost(pfinder_2d_p_m, DirectDistance{2}(), (1, 1), (8, 6)) == 62
    @test delta_cost(pfinder_2d_np_nm, DirectDistance{2}(), (1, 1), (4, 6)) == 80
    @test delta_cost(pfinder_2d_p_nm, DirectDistance{2}(), (1, 1), (8, 6)) == 80

    @test delta_cost(pfinder_2d_np_m, MaxDistance{2}(), (1, 1), (4, 6)) == 5
    @test delta_cost(pfinder_2d_p_m, MaxDistance{2}(), (1, 1), (8, 6)) == 5
    @test delta_cost(pfinder_2d_np_nm, MaxDistance{2}(), (1, 1), (4, 6)) == 5
    @test delta_cost(pfinder_2d_p_nm, MaxDistance{2}(), (1, 1), (8, 6)) == 5

    @test delta_cost(pfinder_2d_np_m, HeightMap(hmap), (1, 1), (4, 6)) == 162
    @test delta_cost(pfinder_2d_p_m, HeightMap(hmap), (1, 1), (8, 6)) == 162
    @test delta_cost(pfinder_2d_np_nm, HeightMap(hmap), (1, 1), (4, 6)) == 180
    @test delta_cost(pfinder_2d_p_nm, HeightMap(hmap), (1, 1), (8, 6)) == 180
end

@testset "pathing" begin
    wlk = fill(true, 7, 6)
    wlk[2:7, 1] .= false
    wlk[7, 3:6] .= false
    wlk[[2:4; 6], 4] .= false
    wlk[2:5, 5] .= false
    wlk[2, 2] = false
    wlk[4, 3] = false
    wlk[5, 3] = false

    pfinder_2d_np_m = AStar{2,false,true}(
        Dict(),
        (7, 6),
        copy(moore),
        0.0,
        wlk,
        DirectDistance{2}(),
    )
    pfinder_2d_np_nm = AStar{2,false,false}(
        Dict(),
        (7, 6),
        copy(vonneumann),
        0.0,
        wlk,
        DirectDistance{2}(),
    )
    pfinder_2d_p_m = AStar{2,true,true}(
        Dict(),
        (7, 6),
        copy(moore),
        0.0,
        wlk,
        DirectDistance{2}(),
    )
    pfinder_2d_p_nm = AStar{2,true,false}(
        Dict(),
        (7, 6),
        copy(vonneumann),
        0.0,
        wlk,
        DirectDistance{2}(),
    )

    p = collect(find_path(pfinder_2d_np_m, (1, 1), (6, 6)))
    @test p == [(1, 2), (1, 3), (1, 4), (1, 5), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)]
    p = collect(find_path(pfinder_2d_np_nm, (1, 1), (6, 6)))
    @test p ==
          [(1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)]
    p = collect(find_path(pfinder_2d_p_m, (1, 1), (6, 6)))
    @test p == [(2, 6), (3, 6), (4, 6), (5, 6), (6, 6)]
    p = collect(find_path(pfinder_2d_p_nm, (1, 1), (6, 6)))
    @test p == [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)]
end
