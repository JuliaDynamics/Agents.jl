using Agents, Test
using Agents.Pathfinding

@testset "AStar" begin
    moore = Pathfinding.moore_neighborhood(2)
    vonneumann = Pathfinding.vonneumann_neighborhood(2)
    gspace = GridSpace((5, 5))
    cspace = ContinuousSpace((5., 5.))
    atol = 0.0001
    @testset "constructors" begin
        # GridSpace
        @test_throws AssertionError AStar(gspace; admissibility = -1.0)
        # Default/DirectDistance metric
        cost = AStar(gspace).cost_metric
        @test typeof(cost) <: DirectDistance{2}
        @test cost.direction_costs == [10, 14]
        @test_throws AssertionError AStar(gspace; cost_metric = DirectDistance{2}([1]))
        @test_throws AssertionError AStar(
            gspace;
            diagonal_movement = false,
            cost_metric = DirectDistance{2}([])
        )

        # MaxDistance metric
        cost = AStar(gspace; cost_metric = MaxDistance{2}()).cost_metric
        @test typeof(cost) <: MaxDistance{2}

        # PenaltyMap metric
        @test_throws TypeError AStar(gspace; cost_metric = PenaltyMap)
        @test_throws AssertionError AStar(gspace; cost_metric = PenaltyMap([1 1]))

        cost = AStar(gspace; cost_metric = PenaltyMap(fill(1, 5, 5))).cost_metric
        @test typeof(cost) <: PenaltyMap{2}
        @test typeof(cost.base_metric) <: DirectDistance{2}
        @test cost.pmap == fill(1, 5, 5)

        cost = AStar(gspace; cost_metric = PenaltyMap(fill(1, 5, 5), MaxDistance{2}())).cost_metric
        @test typeof(cost) <: PenaltyMap{2}
        @test typeof(cost.base_metric) <: MaxDistance{2}
        @test cost.pmap == fill(1, 5, 5)
        pmap = zeros(Int, 1, 1, 1)
        @test_throws TypeError AStar(gspace; cost_metric = PenaltyMap(pmap))

        # ContinuousSpace
        @test_throws AssertionError AStar(cspace; walkmap = trues((10, 10)), cost_metric = PenaltyMap(fill(1, 5, 5)))
        @test_throws AssertionError AStar(cspace; walkmap = trues((10, 10)), cost_metric = PenaltyMap(fill(1, 5, 5)))

        astar = AStar(cspace; walkmap = trues(10, 10))
        @test astar isa AStar{2,true,true,Float64}
        astar = AStar(cspace; cost_metric = PenaltyMap(fill(1, 5, 5)))
        @test astar isa AStar{2,true,true,Float64}
    end

    @testset "API functions" begin
        @testset "GridSpace" begin
            pathfinder = AStar(gspace)
            model = ABM(Agent3, gspace; properties = (pf = pathfinder,))
            a = add_agent!((5, 2), model, 654.5)
            @test is_stationary(a, model.pf)

            plan_route!(a, (1, 3), model.pf)
            @test !is_stationary(a, model.pf)
            @test length(model.pf.agent_paths) == 1

            move_along_route!(a, model, model.pf)
            @test a.pos == (1, 3)

            delete!(model.pf.agent_paths, 1)
            @test length(model.pf.agent_paths) == 0
            @test plan_best_route!(a, [(5, 1), (1, 1), (3, 3)], model.pf) == (5, 1)
            @test length(model.pf.agent_paths) == 1

            kill_agent!(a, model, model.pf)
            @test length(model.pf.agent_paths) == 0

            @test isnothing(penaltymap(model.pf))
            pmap = fill(1, 5, 5)
            pathfinder = AStar(gspace; cost_metric = PenaltyMap(pmap))
            model = ABM(Agent3, gspace; properties = (pf = pathfinder, ))
            @test penaltymap(model.pf) == pmap

            pathfinder.walkmap[:, 3] .= false
            npos = collect(nearby_walkable((5, 4), model, model.pf))
            ans = [(4, 4), (5, 5), (1, 4), (4, 5), (1, 5)]
            @test length(npos) == length(ans)
            @test all(x in npos for x in ans)
            @test all(pathfinder.walkmap[random_walkable(model, model.pf)...] for _ in 1:10)

            sp = GridSpace((5, 5); periodic = false)
            pf = AStar(sp)
            model = ABM(Agent3, sp; properties = (pf = pf,))
            model.pf.walkmap[3, :] .= 0
            a = add_agent!((1, 3), model, 0.)
            @test plan_best_route!(a, [(1, 3), (4, 1)], model.pf) == (1, 3)
            @test isnothing(plan_best_route!(a, [(5, 3), (4, 1)], model.pf))
        end

        @testset "ContinuousSpace" begin
            pathfinder = AStar(cspace; walkmap = trues(10, 10))
            model = ABM(Agent6, cspace; properties = (pf = pathfinder,))
            a = add_agent!((0., 0.), model, (0., 0.), 0.)
            @test is_stationary(a, model.pf)

            plan_route!(a, (4., 4.), model.pf)
            @test !is_stationary(a, model.pf)
            @test length(model.pf.agent_paths) == 1
            move_along_route!(a, model, model.pf, 0.35355)
            @test all(isapprox.(a.pos, (4.75, 4.75); atol))

            # test waypoint skipping
            move_agent!(a, (0.25, 0.25), model)
            plan_route!(a, (0.75, 1.25), model.pf)
            move_along_route!(a, model, model.pf, 0.807106)
            @test all(isapprox.(a.pos, (0.75, 0.849999); atol)) || all(isapprox.(a.pos, (0.467156, 0.967156); atol))
            # make sure it doesn't overshoot the end
            move_along_route!(a, model, model.pf, 20.)
            @test all(isapprox.(a.pos, (0.75, 1.25); atol))

            delete!(model.pf.agent_paths, 1)
            @test length(model.pf.agent_paths) == 0

            model.pf.walkmap[:, 3] .= 0
            @test all(get_spatial_property(random_walkable(model, model.pf), model.pf.walkmap, model) for _ in 1:10)
            rpos = [random_walkable((2.5, 0.75), model, model.pf, 2.0) for _ in 1:50]
            @test all(get_spatial_property(x, model.pf.walkmap, model) && euclidean_distance(x, (2.5, 0.75), model) <= 2.0 + atol for x in rpos)

            pcspace = ContinuousSpace((5., 5.); periodic = false)
            pathfinder = AStar(pcspace; walkmap = trues(10, 10))
            model = ABM(Agent6, pcspace; properties = (pf = pathfinder,))
            a = add_agent!((0., 0.), model, (0., 0.), 0.)
            @test all(plan_best_route!(a, [(2.5, 2.5), (4.99,0.), (0., 4.99)], model.pf) .≈ (2.5, 2.5))
            @test length(model.pf.agent_paths) == 1
            move_along_route!(a, model, model.pf, 1.0)
            @test all(isapprox.(a.pos, (0.7071, 0.7071); atol))

            model.pf.walkmap[:, 3] .= 0
            move_agent!(a, (2.5, 2.5), model)
            @test all(plan_best_route!(a, [(3., 0.3), (2.5, 2.5)], model.pf) .≈ (2.5, 2.5))
            @test isnothing(plan_best_route!(a, [(3., 0.3), (1., 0.1)], model.pf))

            kill_agent!(a, model, model.pf)
            @test length(model.pf.agent_paths) == 0

            @test isnothing(penaltymap(model.pf))
            pmap = fill(1, 10, 10)
            pathfinder = AStar(cspace; cost_metric = PenaltyMap(pmap))
            @test penaltymap(pathfinder) == pmap

            @test all(get_spatial_property(random_walkable(model, model.pf), model.pf.walkmap, model) for _ in 1:10)
            rpos = [random_walkable((2.5, 0.75), model, model.pf, 2.0) for _ in 1:50]
            @test all(get_spatial_property(x, model.pf.walkmap, model) && euclidean_distance(x, (2.5, 0.75), model) <= 2.0 + atol for x in rpos)
        end
    end

    @testset "metrics" begin
        pfinder_2d_np_m = AStar{2,false,true,Int64,DirectDistance{2}}(
            Dict(),
            (10, 10),
            copy(moore),
            0.0,
            trues(10, 10),
            DirectDistance{2}(),
        )
        pfinder_2d_np_nm = AStar{2,false,false,Int64,DirectDistance{2}}(
            Dict(),
            (10, 10),
            copy(vonneumann),
            0.0,
            trues(10, 10),
            DirectDistance{2}(),
        )
        pfinder_2d_p_m = AStar{2,true,true,Int64,DirectDistance{2}}(
            Dict(),
            (10, 10),
            copy(moore),
            0.0,
            trues(10, 10),
            DirectDistance{2}(),
        )
        pfinder_2d_p_nm = AStar{2,true,false,Int64,DirectDistance{2}}(
            Dict(),
            (10, 10),
            copy(vonneumann),
            0.0,
            trues(10, 10),
            DirectDistance{2}(),
        )
        pmap = fill(0, 10, 10)
        pmap[:, 6] .= 100
        pmap[1, 6] = 0

        @test delta_cost(pfinder_2d_np_m, DirectDistance{2}(), (1, 1), (4, 6)) == 62
        @test delta_cost(pfinder_2d_p_m, DirectDistance{2}(), (1, 1), (8, 6)) == 62
        @test delta_cost(pfinder_2d_np_nm, DirectDistance{2}(), (1, 1), (4, 6)) == 80
        @test delta_cost(pfinder_2d_p_nm, DirectDistance{2}(), (1, 1), (8, 6)) == 80

        @test delta_cost(pfinder_2d_np_m, MaxDistance{2}(), (1, 1), (4, 6)) == 5
        @test delta_cost(pfinder_2d_p_m, MaxDistance{2}(), (1, 1), (8, 6)) == 5
        @test delta_cost(pfinder_2d_np_nm, MaxDistance{2}(), (1, 1), (4, 6)) == 5
        @test delta_cost(pfinder_2d_p_nm, MaxDistance{2}(), (1, 1), (8, 6)) == 5

        @test delta_cost(pfinder_2d_np_m, PenaltyMap(pmap), (1, 1), (4, 6)) == 162
        @test delta_cost(pfinder_2d_p_m, PenaltyMap(pmap), (1, 1), (8, 6)) == 162
        @test delta_cost(pfinder_2d_np_nm, PenaltyMap(pmap), (1, 1), (4, 6)) == 180
        @test delta_cost(pfinder_2d_p_nm, PenaltyMap(pmap), (1, 1), (8, 6)) == 180
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

        pfinder_2d_np_m = AStar{2,false,true,Float64,DirectDistance{2}}(
            Dict(),
            (10., 10.),
            copy(moore),
            0.0,
            wlk,
            DirectDistance{2}(),
        )
        pfinder_2d_np_nm = AStar{2,false,false,Float64,DirectDistance{2}}(
            Dict(),
            (10., 10.),
            copy(vonneumann),
            0.0,
            wlk,
            DirectDistance{2}(),
        )
        pfinder_2d_p_m = AStar{2,true,true,Float64,DirectDistance{2}}(
            Dict(),
            (10., 10.),
            copy(moore),
            0.0,
            wlk,
            DirectDistance{2}(),
        )
        pfinder_2d_p_nm = AStar{2,true,false,Float64,DirectDistance{2}}(
            Dict(),
            (10., 10.),
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

        # Continuous
        model = ABM(Agent6, ContinuousSpace((10., 10.)))
        p = collect(Pathfinding.find_continuous_path(pfinder_2d_np_m, (0.25, 0.25), (7.8, 9.5)))
        testp = [(0.71429, 2.5), (0.71429, 4.16667), (0.71429, 5.83333), (0.71429, 7.5), (2.14286, 9.16667), (3.57143, 9.16667), (5.0, 9.16667), (6.42857, 9.16667), (7.85714, 9.16667), (7.8, 9.5)]
        @test length(p) == length(testp)
        @test all(all(isapprox.(p[i], testp[i]; atol)) for i in 1:length(p))

        p = collect(Pathfinding.find_continuous_path(pfinder_2d_p_m, (0.25, 0.25), (7.8, 9.5)))
        testp = [(2.14286, 9.16667), (3.57143, 9.16667), (5.0, 9.16667), (6.42857, 9.16667), (7.85714, 9.16667), (7.8, 9.5)]
        @test length(p) == length(testp)
        @test all(all(isapprox.(p[i], testp[i]; atol)) for i in 1:length(p))
    end
end
