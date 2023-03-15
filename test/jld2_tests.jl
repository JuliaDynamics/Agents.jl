# TODO: Add tests for GridSpaceSingle
# TODO: None of these tests should access internal fields like .stored_ids!
# instead they should use public API like `ids_in_position` etc.
@testset "JLD2" begin

    function test_model_data(model, other)
        @test (model.scheduler isa Function && model.scheduler == other.scheduler) || (!isa(model.scheduler, Function) && typeof(model.scheduler) == typeof(other.scheduler))
        @test model.rng == other.rng
        @test model.maxid.x == other.maxid.x
    end

    function test_space(space::GridSpace, other)
        @test size(space) == size(other)
        @test all(length(other.stored_ids[pos]) == length(space.stored_ids[pos]) for pos in eachindex(space.stored_ids))
        @test all(all(x in other.stored_ids[pos] for x in space.stored_ids[pos]) for pos in eachindex(space.stored_ids))
        @test space.metric == other.metric
    end

    function test_space(space::GridSpaceSingle, other)
        @test size(space) == size(other)
        @test all(other.stored_ids[pos] == space.stored_ids[pos] for pos in eachindex(space.stored_ids))
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
        @test astar.dims == other.dims
        @test astar.neighborhood == other.neighborhood
        @test astar.admissibility == other.admissibility
        @test astar.walkmap == other.walkmap
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
        model = ABM(Agent2, nothing; properties = Dict(:abc => 123), rng = MersenneTwister(42))
        for i in 1:100
            add_agent!(model, rand(model.rng))
        end
        AgentsIO.save_checkpoint("test.jld2", model)
        other = AgentsIO.load_checkpoint("test.jld2")

        # agent data
        @test nagents(other) == nagents(model)
        @test Set(allids(model)) == Set(allids(other))
        @test all(model[i].weight == other[i].weight for i in allids(model))
        # properties
        @test model.abc == other.abc
        # model data
        test_model_data(model, other)

        rm("test.jld2")
    end

    @testset "GridSpace" begin
        model, astep, mstep = Models.schelling()
        step!(model, astep, mstep, 50)
        AgentsIO.save_checkpoint("test.jld2", model)
        other = AgentsIO.load_checkpoint("test.jld2"; scheduler = Schedulers.Randomly())

        # agent data
        @test nagents(other) == nagents(model)
        @test Set(allids(model)) == Set(allids(other))
        @test all(model[i].mood == other[i].mood for i in allids(model))
        @test all(model[i].group == other[i].group for i in allids(model))
        # properties
        @test model.min_to_be_happy == other.min_to_be_happy
        # model data
        test_model_data(model, other)
        # space data
        @test typeof(model.space) == typeof(other.space)    # to check periodicity
        test_space(model.space, other.space)

        rm("test.jld2")
    end

    @testset "GridSpaceSingle" begin
        function schelling_single(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3)
            @assert numagents < prod(griddims)
            space = GridSpaceSingle(griddims, periodic = false)
            properties = Dict(:min_to_be_happy => min_to_be_happy)
            model = ABM(Models.SchellingAgent, space; properties, scheduler = Schedulers.Randomly())
            for n in 1:numagents
                agent = Models.SchellingAgent(n, (1, 1), false, n < numagents / 2 ? 1 : 2)
                add_agent_single!(agent, model)
            end
            return model, Models.schelling_agent_step!, dummystep
        end

        model, astep, mstep = Models.schelling()
        step!(model, astep, mstep, 50)
        AgentsIO.save_checkpoint("test.jld2", model)
        other = AgentsIO.load_checkpoint("test.jld2"; scheduler = Schedulers.Randomly())

        # agent data
        @test nagents(other) == nagents(model)
        @test Set(allids(model)) == Set(allids(other))
        @test all(model[i].mood == other[i].mood for i in allids(model))
        @test all(model[i].group == other[i].group for i in allids(model))
        # properties
        @test model.min_to_be_happy == other.min_to_be_happy
        # model data
        test_model_data(model, other)
        # space data
        @test typeof(model.space) == typeof(other.space)    # to check periodicity
        test_space(model.space, other.space)

        rm("test.jld2")
    end

    @testset "ContinuousSpace" begin
        model, astep, mstep = Models.flocking(n_birds = 300)
        step!(model, astep, mstep, 100)
        AgentsIO.save_checkpoint("test.jld2", model)
        other = AgentsIO.load_checkpoint("test.jld2"; scheduler = Schedulers.Randomly())

        # agent data
        @test nagents(other) == nagents(model)
        @test Set(allids(model)) == Set(allids(other))
        @test all(model[i].pos == other[i].pos for i in allids(model))
        @test all(model[i].vel == other[i].vel for i in allids(model))
        @test all(model[i].speed == other[i].speed for i in allids(model))
        @test all(model[i].cohere_factor == other[i].cohere_factor for i in allids(model))
        @test all(model[i].separation == other[i].separation for i in allids(model))
        @test all(model[i].separate_factor == other[i].separate_factor for i in allids(model))
        @test all(model[i].match_factor == other[i].match_factor for i in allids(model))
        @test all(model[i].visual_distance == other[i].visual_distance for i in allids(model))
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
            properties = ModelData(3, 4.2f32, Dict(1 => "foo", 2 => "bar")),
            rng = MersenneTwister(42)
        )

        for i in 1:30
            add_agent_pos!(Agent7(i, i % 10 + 1, rand(model.rng) < 0.5, rand(model.rng, Int)), model)
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
        @test length(model.space.stored_ids) == length(other.space.stored_ids)
        @test all(length(model.space.stored_ids[pos]) == length(other.space.stored_ids[pos]) for pos in eachindex(model.space.stored_ids))
        @test all(all(x in other.space.stored_ids[pos] for x in model.space.stored_ids[pos]) for pos in eachindex(model.space.stored_ids))

        rm("test.jld2")
    end

    @testset "Grid Pathfinder" begin
        astep!(a, m) = move_along_route!(a, m, m.pathfinder)
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
                properties = (pathfinder = pathfinder,),
                rng = MersenneTwister(42)
            )
            add_agent!((1, 1), model)
            plan_route!(model[1], (10, 10), model.pathfinder)
            step!(model, astep!, dummystep)

            AgentsIO.save_checkpoint("test.jld2", model)
            other = AgentsIO.load_checkpoint("test.jld2")
            return model, other
        end

        test_pathfinding_model(setup_model()...)
        test_pathfinding_model(setup_model(; diagonal_movement = true)...)
        test_pathfinding_model(setup_model(; admissibility = 0.5)...)
        test_pathfinding_model(setup_model(; walkmap = walk)...)
        test_pathfinding_model(setup_model(; cost_metric = direct)...)
        test_pathfinding_model(setup_model(; cost_metric = maxd)...)
        test_pathfinding_model(setup_model(; cost_metric = hmm)...)
        test_pathfinding_model(setup_model(; cost_metric = Pathfinding.PenaltyMap(pmap, direct))...)
        test_pathfinding_model(setup_model(; cost_metric = Pathfinding.PenaltyMap(pmap, maxd))...)
        test_pathfinding_model(setup_model(; cost_metric = Pathfinding.PenaltyMap(pmap, hmm))...)

        rm("test.jld2")
    end

    @testset "Continuous Pathfinder" begin
        astep!(a, m) = move_along_route!(a, m, m.pathfinder, 0.89, 0.56)
        walk = BitArray(fill(true, 10, 10))
        walk[2, 2] = false
        walk[9, 9] = false
        pmap = abs.(rand(Int, 10, 10)) .% 10
        direct = Pathfinding.DirectDistance{2}([0, 10])
        maxd = Pathfinding.MaxDistance{2}()
        hmm = Pathfinding.PenaltyMap(pmap)

        function setup_model(; kwargs...)
            space = ContinuousSpace((10.0, 10.0); periodic = false)
            pathfinder = Pathfinding.AStar(space; kwargs...)
            model = ABM(
                Agent6,
                deepcopy(space);
                properties = (pathfinder = pathfinder,),
                rng = MersenneTwister(42)
            )
            add_agent!((1.3, 1.5), model, (0.0, 0.0), 0.0)
            plan_route!(model[1], (9.7, 4.8), model.pathfinder)
            step!(model, astep!, dummystep)

            AgentsIO.save_checkpoint("test.jld2", model)
            other = AgentsIO.load_checkpoint("test.jld2")
            return model, other
        end

        test_pathfinding_model(setup_model(walkmap = trues(10, 10))...)
        test_pathfinding_model(setup_model(walkmap = trues(10, 10), admissibility = 0.5)...)
        test_pathfinding_model(setup_model(walkmap = walk)...)
        test_pathfinding_model(setup_model(walkmap = trues(10, 10), cost_metric = direct)...)
        test_pathfinding_model(setup_model(walkmap = trues(10, 10), cost_metric = maxd)...)
        test_pathfinding_model(setup_model(walkmap = trues(10, 10), cost_metric = hmm)...)
        test_pathfinding_model(setup_model(cost_metric = Pathfinding.PenaltyMap(pmap, direct))...)
        test_pathfinding_model(setup_model(cost_metric = Pathfinding.PenaltyMap(pmap, maxd))...)
        test_pathfinding_model(setup_model(cost_metric = Pathfinding.PenaltyMap(pmap, hmm))...)

        rm("test.jld2")
    end

    @testset "Multi-agent" begin
        model = ABM(Union{Agent1,Agent3}, GridSpace((10, 10)); warn = false)
        AgentsIO.save_checkpoint("test.jld2", model)
        other = @test_nowarn AgentsIO.load_checkpoint("test.jld2"; warn = false)

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].pos == other[i].pos for i in allids(model))
        @test all(model[i].weight == other[i].weight for i in allids(model) if model[i] isa Agent3)
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
        model = ABM(Zombie, OpenStreetMapSpace(OSM.test_map()); rng = MersenneTwister(42))

        for id in 1:100
            start = random_position(model)
            finish = OSM.random_road_position(model)
            human = Zombie(id, start, false)
            add_agent_pos!(human, model)
            plan_route!(human, finish, model)
        end

        start = OSM.nearest_road((51.530876112711745, 9.945125635913511), model)
        finish = OSM.nearest_node((51.5328328, 9.9351811), model)
        zombie = add_agent!(start, model, true)
        plan_route!(zombie, finish, model)

        AgentsIO.save_checkpoint("test.jld2", model)
        @test_throws AssertionError AgentsIO.load_checkpoint("test.jld2")
        other = AgentsIO.load_checkpoint("test.jld2"; map = OSM.test_map())

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(OSM.latlon(model[i].pos, model) == OSM.latlon(other[i].pos, other) for i in allids(model))
        @test all(model[i].infected == other[i].infected for i in allids(model))
        # model data
        test_model_data(model, other)
        @test sort(collect(keys(model.space.routes))) == sort(collect(keys(other.space.routes)))
        @test all(model.space.routes[i].route == other.space.routes[i].route for i in keys(model.space.routes))
        @test all(model.space.routes[i].start == other.space.routes[i].start for i in keys(model.space.routes))
        @test all(model.space.routes[i].dest == other.space.routes[i].dest for i in keys(model.space.routes))
        @test all(model.space.routes[i].return_route == other.space.routes[i].return_route for i in keys(model.space.routes))
        @test all(model.space.routes[i].has_to_return == other.space.routes[i].has_to_return for i in keys(model.space.routes))

        rm("test.jld2")
    end
end
