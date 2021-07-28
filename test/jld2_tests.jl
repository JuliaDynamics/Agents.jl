@testset "JLD2" begin

    function test_model_data(model, other)
        @test model.scheduler == other.scheduler
        @test model.rng == other.rng
        @test model.maxid.x == other.maxid.x
    end

    function test_space(space::GridSpace, other)
        @test size(space.s) == size(other.s)
        @test all(length(other.s[pos]) == length(space.s[pos]) for pos in eachindex(space.s))
        @test all(all(x in other.s[pos] for x in space.s[pos]) for pos in eachindex(space.s))
        @test space.metric == other.metric
    end

    function test_space(space::ContinuousSpace, other)
        test_space(space.grid, other.grid)
        @test space.update_vel! == other.update_vel!
        @test space.dims == other.dims
        @test space.spacing == other.spacing
        @test space.extent == other.extent
    end

    test_costmetric(metric, other) = @test false
    test_costmetric(
        metric::Pathfinding.DirectDistance{D},
        other::Pathfinding.DirectDistance{D}
    ) where {D} = @test metric.direction_costs == other.direction_costs

    test_costmetric(
        metric::Pathfinding.MaxDistance{D},
        other::Pathfinding.MaxDistance{D}
    ) where {D} = @test true

    function test_costmetric(
        metric::Pathfinding.PenaltyMap{D},
        other::Pathfinding.PenaltyMap{D}
    ) where {D}
        @test metric.pmap == other.pmap
        test_costmetric(metric.base_metric, other.base_metric)
    end


    function test_astar(astar, other)
        @test typeof(astar) == typeof(other)
        @test astar.agent_paths == other.agent_paths
        @test astar.grid_dims == other.grid_dims
        @test astar.neighborhood == other.neighborhood
        @test astar.admissibility == other.admissibility
        @test astar.walkable == other.walkable
        test_costmetric(astar.cost_metric, other.cost_metric)
    end

    function test_pathfinding_model(model, other)
        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].pos == other[i].pos for i in allids(model))
        # model data
        test_model_data(model, other)
        # space data
        @test typeof(model.space) == typeof(other.space)    # to check periodicity
        test_space(model.space, other.space)
        # pathfinder data
        test_astar(model.pathfinder, other.pathfinder)
    end

    @testset "No space" begin
        model, _ = Models.hk()
        AgentsIO.save_checkpoint("test.jld2", model)
        other = AgentsIO.load_checkpoint("test.jld2")

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].old_opinion == other[i].old_opinion for i in allids(model))
        @test all(model[i].new_opinion == other[i].new_opinion for i in allids(model))
        @test all(model[i].previous_opinion == other[i].previous_opinion for i in allids(model))
        # properties
        @test model.ϵ == other.ϵ
        # model data
        test_model_data(model, other)

        rm("test.jld2")
    end

    @testset "GridSpace" begin
        # predator_prey used since properties is a NamedTuple, and contains an Array
        model, astep, mstep = Models.predator_prey()
        step!(model, astep, mstep, 50)
        AgentsIO.save_checkpoint("test.jld2", model)
        other = AgentsIO.load_checkpoint("test.jld2"; scheduler = Schedulers.by_property(:type))
        
        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].type == other[i].type for i in allids(model))
        @test all(model[i].energy == other[i].energy for i in allids(model))
        @test all(model[i].reproduction_prob == other[i].reproduction_prob for i in allids(model))
        @test all(model[i].Δenergy == other[i].Δenergy for i in allids(model))
        # properties
        @test model.fully_grown == other.fully_grown
        @test model.countdown == other.countdown
        @test model.regrowth_time == other.regrowth_time
        # model data
        test_model_data(model, other)
        # space data
        @test typeof(model.space) == typeof(other.space)    # to check periodicity
        test_space(model.space, other.space)

        rm("test.jld2")
    end

    @testset "ContinuousSpace" begin
        model, astep, mstep = Models.social_distancing(N = 300)
        step!(model, astep, mstep, 100)
        AgentsIO.save_checkpoint("test.jld2", model)
        other = AgentsIO.load_checkpoint("test.jld2")

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].pos == other[i].pos for i in allids(model))
        @test all(model[i].vel == other[i].vel for i in allids(model))
        @test all(model[i].mass == other[i].mass for i in allids(model))
        @test all(model[i].days_infected == other[i].days_infected for i in allids(model))
        @test all(model[i].status == other[i].status for i in allids(model))
        @test all(model[i].β == other[i].β for i in allids(model))
        # properties
        @test model.infection_period == other.infection_period
        @test model.reinfection_probability == other.reinfection_probability
        @test model.detection_time == other.detection_time
        @test model.death_rate == other.death_rate
        @test model.interaction_radius == other.interaction_radius
        @test model.dt == other.dt
        # model data
        test_model_data(model, other)
        # space data
        @test typeof(model.space) == typeof(other.space)    # to check periodicity
        test_space(model.space, other.space)

        rm("test.jld2")
    end

    @testset "GraphSpace" begin
        struct ModelData
            i::Int
            f::Float32
            d::Dict{Int,String}
        end

        model = ABM(
            Agent7,
            GraphSpace(complete_graph(10));
            properties = ModelData(3, 4.2f32, Dict(1=>"foo", 2=>"bar")),
            rng = MersenneTwister(42)
        )

        for i in 1:30
            add_agent_pos!(Agent7(i, i%10 + 1, rand(model.rng) < 0.5, rand(model.rng, Int)), model)
        end

        AgentsIO.save_checkpoint("test.jld2", model)
        other = AgentsIO.load_checkpoint("test.jld2")

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].pos == other[i].pos for i in allids(model))
        @test all(model[i].f1 == other[i].f1 for i in allids(model))
        @test all(model[i].f2 == other[i].f2 for i in allids(model))
        # properties
        @test model.i == other.i
        @test model.f == other.f
        @test all(haskey(other.d, k) for k in keys(model.d))
        @test all(other.d[k] == v for (k, v) in model.d)
        # model data
        test_model_data(model, other)
        # space data
        @test model.space.graph == other.space.graph
        @test length(model.space.s) == length(other.space.s)
        @test all(length(model.space.s[pos]) == length(other.space.s[pos]) for pos in eachindex(model.space.s))
        @test all(all(x in other.space.s[pos] for x in model.space.s[pos]) for pos in eachindex(model.space.s))

        rm("test.jld2")
    end

    @testset "Grid Pathfinder" begin
        astep!(a, m) = Pathfinding.move_along_route!(a, m, m.pathfinder)
        walk = BitArray(fill(true, 10, 10))
        walk[2, 2] = false
        walk[9, 9] = false
        pmap = abs.(rand(Int, 10, 10)) .% 10
        direct = Pathfinding.DirectDistance{2}([0, 10])
        maxd = Pathfinding.MaxDistance{2}()
        hmm = Pathfinding.PenaltyMap(pmap)

        function setup_model(; kwargs...)
            space = GridSpace((10, 10); periodic = false)
            pathfinder = Pathfinding.AStar(space; kwargs...)
            model = ABM(
                Agent1,
                space;
                properties = (pathfinder = pathfinder, ),
                rng = MersenneTwister(42)
            )
            add_agent!((1, 1), model)
            Pathfinding.set_target!(model[1], (10, 10), model.pathfinder)
            step!(model, astep!, dummystep)

            AgentsIO.save_checkpoint("test.jld2", model)
            other = AgentsIO.load_checkpoint("test.jld2")
            return model, other
        end
        
        test_pathfinding_model(setup_model()...)
        test_pathfinding_model(setup_model(; diagonal_movement = true)...)
        test_pathfinding_model(setup_model(; admissibility = 0.5)...)
        test_pathfinding_model(setup_model(; walkable = walk)...)
        test_pathfinding_model(setup_model(; cost_metric = direct)...)
        test_pathfinding_model(setup_model(; cost_metric = maxd)...)
        test_pathfinding_model(setup_model(; cost_metric = hmm)...)
        test_pathfinding_model(setup_model(; cost_metric = Pathfinding.PenaltyMap(pmap, direct))...)
        test_pathfinding_model(setup_model(; cost_metric = Pathfinding.PenaltyMap(pmap, maxd))...)
        test_pathfinding_model(setup_model(; cost_metric = Pathfinding.PenaltyMap(pmap, hmm))...)

        rm("test.jld2")
    end

    @testset "Continuous Pathfinder" begin
        astep!(a, m) = Pathfinding.move_along_route!(a, m, m.pathfinder, 0.89, 0.56)
        walk = BitArray(fill(true, 10, 10))
        walk[2, 2] = false
        walk[9, 9] = false
        pmap = abs.(rand(Int, 10, 10)) .% 10
        direct = Pathfinding.DirectDistance{2}([0, 10])
        maxd = Pathfinding.MaxDistance{2}()
        hmm = Pathfinding.PenaltyMap(pmap)
        space = ContinuousSpace((10., 10.); periodic = false)

        function setup_model(pathfinder)
            model = ABM(
                Agent6,
                deepcopy(space);
                properties = (pathfinder = pathfinder, ),
                rng = MersenneTwister(42)
            )
            add_agent!((1.3, 1.5), model, (0., 0.), 0.)
            Pathfinding.set_target!(model[1], (9.7, 4.8), model.pathfinder, model)
            step!(model, astep!, dummystep)

            AgentsIO.save_checkpoint("test.jld2", model)
            other = AgentsIO.load_checkpoint("test.jld2")
            return model, other
        end

        test_pathfinding_model(setup_model(Pathfinding.AStar(space, trues(10, 10)))...)
        test_pathfinding_model(setup_model(Pathfinding.AStar(space, trues(10, 10); admissibility = 0.5))...)
        test_pathfinding_model(setup_model(Pathfinding.AStar(space, walk))...)
        test_pathfinding_model(setup_model(Pathfinding.AStar(space, trues(10, 10); cost_metric = direct))...)
        test_pathfinding_model(setup_model(Pathfinding.AStar(space, trues(10, 10); cost_metric = maxd))...)
        test_pathfinding_model(setup_model(Pathfinding.AStar(space, trues(10, 10); cost_metric = hmm))...)
        test_pathfinding_model(setup_model(Pathfinding.AStar(space, Pathfinding.PenaltyMap(pmap, direct)))...)
        test_pathfinding_model(setup_model(Pathfinding.AStar(space, Pathfinding.PenaltyMap(pmap, maxd)))...)
        test_pathfinding_model(setup_model(Pathfinding.AStar(space, Pathfinding.PenaltyMap(pmap, hmm)))...)

        rm("test.jld2")
    end
    
    @testset "Multi-agent" begin
        model, _ = Models.daisyworld()
        AgentsIO.save_checkpoint("test.jld2", model)
        other = @test_nowarn AgentsIO.load_checkpoint("test.jld2"; scheduler = Models.daisysched, warn = false)

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].pos == other[i].pos for i in allids(model))
        @test all(model[i].temperature == other[i].temperature for i in allids(model) if model[i] isa Models.Land)
        @test all(model[i].breed == other[i].breed for i in allids(model) if model[i] isa Models.Daisy)
        @test all(model[i].age == other[i].age for i in allids(model) if model[i] isa Models.Daisy)
        @test all(model[i].albedo == other[i].albedo for i in allids(model) if model[i] isa Models.Daisy)
        # properties
        @test model.max_age == other.max_age
        @test model.surface_albedo == other.surface_albedo
        @test model.solar_luminosity == other.solar_luminosity
        @test model.solar_change == other.solar_change
        @test model.scenario == other.scenario
        @test model.tick == other.tick
        # model data
        test_model_data(model, other)
        # space data
        test_space(model.space, other.space)

        rm("test.jld2")
    end

    @testset "OSMSpace" begin
        @agent Zombie OSMAgent begin
            infected::Bool
        end
        model = ABM(Zombie, OpenStreetMapSpace(OSM.TEST_MAP))
        
        for id in 1:100
            start = random_position(model)
            finish = OSM.random_road_position(model)
            route = OSM.plan_route(start, finish, model)
            human = Zombie(id, start, route, finish, false)
            add_agent_pos!(human, model)
        end
        
        start = OSM.road((39.52320181536525, -119.78917553184259), model)
        finish = OSM.intersection((39.510773, -119.75916700000002), model)
        route = OSM.plan_route(start, finish, model)
        zombie = add_agent!(start, model, route, finish, true)

        AgentsIO.save_checkpoint("test.jld2", model)
        @test_throws AssertionError AgentsIO.load_checkpoint("test.jld2")
        other = AgentsIO.load_checkpoint("test.jld2"; map = OSM.TEST_MAP)

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(OSM.latlon(model[i].pos, model) == OSM.latlon(other[i].pos, other) for i in allids(model))
        @test all(OSM.latlon(model[i].destination, model) == OSM.latlon(other[i].destination, other) for i in allids(model))
        @test all(length(model[i].route) == length(other[i].route) for i in allids(model))
        @test all(all(OSM.latlon(model[i].route[j], model) == OSM.latlon(other[i].route[j], other) for j in 1:length(model[i].route)) for i in allids(model))
        @test all(model[i].infected == other[i].infected for i in allids(model))
        # model data
        test_model_data(model, other)

        rm("test.jld2")
    end
end
