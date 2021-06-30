@testset "Pathfinding" begin
    using Agents.Pathfinding

    moore = Pathfinding.moore_neighborhood(2)
    vonneumann = Pathfinding.vonneumann_neighborhood(2)
    space = GridSpace((5, 5))
    @testset "constructors" begin
        @test_throws AssertionError AStar(space; admissibility = -1.0)
        # Default/DirectDistance metric
        cost = AStar(space).cost_metric
        @test typeof(cost) <: DirectDistance{2}
        @test cost.direction_costs == [10, 14]
        @test_throws AssertionError AStar(space; cost_metric = DirectDistance{2}([1]))
        @test_throws AssertionError AStar(
            space;
            diagonal_movement = false,
            cost_metric = DirectDistance{2}([])
        )
        
        # MaxDistance metric
        cost = AStar(space; cost_metric = MaxDistance{2}()).cost_metric
        @test typeof(cost) <: MaxDistance{2}

        # HeightMap metric
        @test_throws TypeError AStar(space; cost_metric = HeightMap)
        @test_throws AssertionError AStar(space; cost_metric = HeightMap([1 1]))
        
        cost = AStar(space; cost_metric = HeightMap(fill(1, 5, 5))).cost_metric
        @test typeof(cost) <: HeightMap{2}
        @test typeof(cost.base_metric) <: DirectDistance{2}
        @test cost.hmap == fill(1, 5, 5)

        cost = AStar(space; cost_metric = HeightMap(fill(1, 5, 5), MaxDistance{2}())).cost_metric
        @test typeof(cost) <: HeightMap{2}
        @test typeof(cost.base_metric) <: MaxDistance{2}
        @test cost.hmap == fill(1, 5, 5)
        hmap = zeros(Int, 1, 1, 1)
        @test_throws TypeError AStar(space; cost_metric = HeightMap(hmap))
    end

    @testset "API functions" begin
        pathfinder = AStar(space)
        model = ABM(Agent3, space; properties = (pf = pathfinder,))
        a = add_agent!((5, 2), model, 654.5)
        @test is_stationary(a, model.pf)
        
        set_target!(a, (1, 3), model.pf)
        @test !is_stationary(a, model.pf)
        @test length(model.pf.agent_paths) == 1
        
        move_along_route!(a, model, model.pf)
        @test a.pos == (1, 3)

        delete!(model.pf.agent_paths, 1)
        @test length(model.pf.agent_paths) == 0
        @test set_best_target!(a, [(5, 1), (1, 1), (3, 3)], model.pf) == (5, 1)
        @test length(model.pf.agent_paths) == 1

        kill_agent!(a, model, model.pf)
        @test length(model.pf.agent_paths) == 0
        @test heightmap(model.pf) === nothing

        hmap = fill(1, 5, 5)
        pathfinder = AStar(space; cost_metric = HeightMap(hmap))
        model = ABM(Agent3, space; properties = (pf = pathfinder, ))
        @test heightmap(model.pf) == hmap
    end

    @testset "metrics" begin
        pfinder_2d_np_m = AStar{2,false,true}(
            Dict(),
            (10, 10),
            copy(moore),
            0.0,
            trues(10, 10),
            DirectDistance{2}(),
        )
        pfinder_2d_np_nm = AStar{2,false,false}(
            Dict(),
            (10, 10),
            copy(vonneumann),
            0.0,
            trues(10, 10),
            DirectDistance{2}(),
        )
        pfinder_2d_p_m = AStar{2,true,true}(
            Dict(),
            (10, 10),
            copy(moore),
            0.0,
            trues(10, 10),
            DirectDistance{2}(),
        )
        pfinder_2d_p_nm = AStar{2,true,false}(
            Dict(),
            (10, 10),
            copy(vonneumann),
            0.0,
            trues(10, 10),
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
        wlk = trues(7, 6)
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

        p = collect(Pathfinding.find_path(pfinder_2d_np_m, (1, 1), (6, 6)))
        @test p == [(1, 2), (1, 3), (1, 4), (1, 5), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)]
        p = collect(Pathfinding.find_path(pfinder_2d_np_nm, (1, 1), (6, 6)))
        @test p ==
            [(1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)]
        p = collect(Pathfinding.find_path(pfinder_2d_p_m, (1, 1), (6, 6)))
        @test p == [(2, 6), (3, 6), (4, 6), (5, 6), (6, 6)]
        p = collect(Pathfinding.find_path(pfinder_2d_p_nm, (1, 1), (6, 6)))
        @test p == [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)]
    end
end
