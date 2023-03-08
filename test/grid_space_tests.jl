using Test, Agents, Random
using StableRNGs

@testset "$(SpaceType)" for SpaceType in (GridSpace, GridSpaceSingle)
    @testset "size, dim=$D" for D in (1,3)
        dims = (fill(5, D)...,)
        for periodic in (true, false)
            space = SpaceType(dims; periodic)
            poss = positions(space)
            @test spacesize(space) == dims
            @test size(poss) == dims
            @test size(space) == dims
        end
    end

    @testset "add/move/remove" begin
        space = SpaceType((3, 3))
        model = ABM(GridAgent{2}, space; rng = StableRNG(42))
        pos0 = (2,2)
        agent = add_agent!(pos0, model)
        id0 = agent.id
        @test collect(allids(model)) == [1]
        @test model[1].pos == agent.pos == pos0
        move_agent!(agent, (3,3), model)
        @test agent.pos == (3,3)
        move_agent!(agent, model)
        @test agent.pos != (3,3)
        move_agent!(agent, (2,2), model)
        remove_agent!(agent, model)
        @test id0 ∉ allids(model)
        # Test move single
        fill_space!(model)
        agent = model[2]
        posx = agent.pos
        remove_agent!(agent, model)
        # now the only position that is left unoccupied is `posx`
        agent = model[3]
        move_agent_single!(agent, model)
        @test agent.pos == posx
    end

    @testset "positions + empty" begin
        space = SpaceType((3, 3))
        model = ABM(GridAgent{2}, space)
        empty = collect(empty_positions(model))
        @test length(empty) == 9
        locs_to_add = [1, 2, 3, 4, 5, 6, 9]
        for n in locs_to_add
            add_agent!(empty[n], model)
        end
        # only positions (1,3) and (2,3) should be empty
        @test random_empty(model) ∈ [(1, 3), (2, 3)]
        empty = collect(empty_positions(model))
        @test empty == [(1, 3), (2, 3)]

        pos_map = [
            (1, 1) (1, 2) (1, 3)
            (2, 1) (2, 2) (2, 3)
            (3, 1) (3, 2) (3, 3)
        ]
        @test collect(positions(model)) == pos_map

        random_positions = positions(model, :random)
        @test all(n ∈ pos_map for n in random_positions)

        # Also test ids_in_position stuff for GridSpace
        if SpaceType == GridSpace
            pos1 = ids_in_position((1, 3), model)
            @test isempty(pos1)
            pos2 = ids_in_position((1, 1), model)
            @test length(pos2) == 1
            @test pos2[1] == 1

            @test positions(model, :population) ==
                [pos_map[i] for i in [1, 2, 3, 4, 5, 6, 9, 7, 8]]
            @test length(ids_in_position(5, model)) > length(ids_in_position(7, model))
            @test_throws ErrorException positions(model, :notreal)
        end
    end

    @testset "Distances" begin
    @testset "Euclidean distance" begin
        model = ABM(GridAgent{2}, SpaceType((12, 10); periodic = true))
        a = add_agent!((1.0, 6.0), model)
        b = add_agent!((11.0, 4.0), model)
        @test euclidean_distance(a, b, model) ≈ 2.82842712

        model = ABM(GridAgent{2}, SpaceType((12, 10); periodic = false))
        a = add_agent!((1.0, 6.0), model)
        b = add_agent!((11.0, 4.0), model)
        @test euclidean_distance(a, b, model) ≈ 10.198039
    end
    @testset "Manhattan Distance" begin
        model = ABM(GridAgent{2}, SpaceType((12, 10); metric = :manhattan, periodic = true))
        a = add_agent!((1.0, 6.0), model)
        b = add_agent!((11.0, 4.0), model)
        @test manhattan_distance(a, b, model) ≈ 4

        model = ABM(GridAgent{2}, SpaceType((12, 10); metric = :manhattan, periodic = false))
        a = add_agent!((1.0, 6.0), model)
        b = add_agent!((11.0, 4.0), model)
        @test manhattan_distance(a, b, model) ≈ 12
    end
    end

    @testset "Nearby pos/ids/agents" begin
        metrics = [:euclidean, :manhattan, :chebyshev]
        periodics = [false, true]

        # All following are with r=1
        @testset "periodic=$(periodic)" for periodic in periodics
            @testset "Metric=$(metric)" for metric in metrics
                # To undersatnd where the numbers here are coming from,
                # check out the plot in the docs that shows the metrics
                model = ABM(GridAgent{2}, SpaceType((5, 5); metric, periodic))
                if metric ∈ (:euclidean, :mahnattan) # for r = 1 they give the same
                    @test sort!(collect(nearby_positions((2, 2), model))) ==
                        sort!([(2, 1), (1, 2), (3, 2), (2, 3)])
                    if !periodic
                        @test sort!(collect(nearby_positions((1, 1), model))) ==
                        sort!([(1, 2), (2, 1)])
                    else # in periodic case we still have all nearby 4 positions
                        @test sort!(collect(nearby_positions((1, 1), model))) ==
                        sort!([(1, 2), (2, 1), (1 ,5), (5, 1)])
                    end
                elseif metric == :chebyshev
                    @test sort!(collect(nearby_positions((2, 2), model))) ==
                        [(1,1), (1,2), (1,3), (2,1), (2,3), (3,1), (3,2), (3,3)]
                    if !periodic
                        @test sort!(collect(nearby_positions((1, 1), model))) ==
                            [(1,2), (2,1), (2,2)]
                    else
                        @test sort!(collect(nearby_positions((1, 1), model))) ==
                            [(1,2), (1,5), (2,1), (2,2), (2,5), (5,1), (5,2), (5,5)]
                    end
                end

                remove_all!(model)
                add_agent!((1, 1), model)
                a = add_agent!((2, 1), model)
                add_agent!((3, 2), model) # this is neighbor only in chebyshev
                add_agent!((5, 1), model)

                near_agent = sort!(collect(nearby_ids(a, model)))
                near_pos = sort!(collect(nearby_ids(a.pos, model)))
                @test 2 ∈ near_pos
                @test 2 ∉ near_agent
                @test near_pos == sort!(vcat(near_agent, 2))

                if !periodic && metric ∈ (:euclidean, :mahnattan)
                    near_agent == [1]
                elseif periodic && metric ∈ (:euclidean, :mahnattan)
                    near_agent == [1,4]
                elseif !periodic && metric == :chebyshev
                    near_agent == [1,3]
                elseif periodic && metric == :chebyshev
                    near_agent == [1,3,4]
                end

            end
            # also test larger r. See figure at docs for metrics to get the numbers
            models = [ABM(GridAgent{2}, SpaceType((9, 9); metric, periodic)) for metric in metrics]
            for m in models; fill_space!(m); end
            near_pos = [collect(nearby_positions((5,5), m, 3.4)) for m in models]
            near_ids = [collect(nearby_ids((5,5), m, 3.4)) for m in models] # this is 1 more
            @test length(near_pos[1]) == length(near_pos[2]) + 12
            @test length(near_pos[3]) == 7^2 - 1
            @test length(near_ids[1]) == length(near_ids[2]) + 12
            @test length(near_ids[1]) == length(near_pos[1]) + 1
            @test length(near_ids[3]) == 7^2
        end
    end

    @testset "Random nearby" begin
        # Test random_nearby_*
        abm = ABM(GridAgent{2}, GridSpace((10, 10)); rng = StableRNG(42))
        fill_space!(abm)

        nearby_id = random_nearby_id(abm[1], abm, 5)
        valid_ids = collect(nearby_ids(abm[1], abm, 5))
        @test nearby_id in valid_ids
        nearby_agent = random_nearby_agent(abm[1], abm, 5)
        @test nearby_agent.id in valid_ids

        remove_all!(abm)
        a = add_agent!((1, 1), abm)
        @test isnothing(random_nearby_id(a, abm))
        @test isnothing(random_nearby_agent(a, abm))
        add_agent!((1,2), abm)
        add_agent!((2,1), abm)
        rand_nearby_ids = Set([random_nearby_id(a, abm, 2) for _ in 1:100])
        @test length(rand_nearby_ids) == 2
    end

    @testset "walk!" begin
        # Periodic
        model = ABM(GridAgent{2}, GridSpace((3, 3); periodic = true))
        a = add_agent!((1, 1), model)
        walk!(a, (0, 1), model) # North
        @test a.pos == (1, 2)
        walk!(a, (1, 1), model) # North east
        @test a.pos == (2, 3)
        walk!(a, (1, 0), model) # East
        @test a.pos == (3, 3)
        walk!(a, (2, 0), model) # PBC, East two steps
        @test a.pos == (2, 3)
        walk!(a, (1, -1), model) # South east
        @test a.pos == (3, 2)
        walk!(a, (0, -1), model) # South
        @test a.pos == (3, 1)
        walk!(a, (-1, -1), model) # PBC, South west
        @test a.pos == (2, 3)
        walk!(a, (-1, 0), model) # West
        @test a.pos == (1, 3)
        walk!(a, (0, -8), model) # Round the world, South eight steps
        @test a.pos == (1, 1)
        # if empty
        a = add_agent!((1, 1), model)
        add_agent!((2, 2), model)
        walk!(a, (1, 1), model; ifempty = true)
        @test a.pos == (1, 1)
        walk!(a, (1, 0), model; ifempty = true)
        @test a.pos == (2, 1)
        # aperiodic
        model = ABM(GridAgent{2}, GridSpace((3, 3); periodic = false))
        a = add_agent!((1, 1), model)
        walk!(a, (0, 1), model) # North
        @test a.pos == (1, 2)
        walk!(a, (1, 1), model) # North east
        @test a.pos == (2, 3)
        walk!(a, (1, 0), model) # East
        @test a.pos == (3, 3)
        walk!(a, (1, 0), model) # Boundary, attempt East
        @test a.pos == (3, 3)
        walk!(a, (-5, 0), model) # Boundary, attempt West five steps
        @test a.pos == (1, 3)
        walk!(a, (-1, -1), model) # Boundary in one direction, not in the other, attempt South west
        @test a.pos == (1, 2)
        @test_throws MethodError walk!(a, (1.0, 1.5), model) # Must use Int for gridspace

        # GridSpaceSingle
        model = ABM(GridAgent{2}, GridSpaceSingle((5, 5)))
        a = add_agent!((3, 3), model)
        walk!(a, (1, 1), model)
        a.pos == (4, 4)

        # Just a single sanity test for higher dimensions, just in case
        model = ABM(GridAgent{3}, GridSpace((3, 3, 2)))
        a = add_agent!((1, 1, 1), model)
        walk!(a, (1, 1, 1), model)
        @test a.pos == (2, 2, 2)
    end

    @testset "random walk" begin
        # random walks on grid spaces with euclidean metric are not defined
        space = SpaceType((10,10), metric=:euclidean)
        model = ABM(GridAgent{2}, space)
        add_agent!(model)
        r = 1.0
        @test_throws ArgumentError randomwalk!(model.agents[1], model, r)

        # chebyshev metric
        space = SpaceType((100,100), metric=:chebyshev)
        model = ABM(GridAgent{2}, space)
        x₀ = (50,50)
        add_agent!(x₀, model)
        r = 1.5
        randomwalk!(model.agents[1], model, r)
        x₁ = model.agents[1].pos
        # chebyshev distance after the random step should be 1
        @test maximum(abs.(x₁ .- x₀)) == 1
        # for r < 1 the agent should not move
        r = 0.5
        randomwalk!(model.agents[1], model, r)
        @test model.agents[1].pos == x₁

        # manhattan metric
        space = SpaceType((100,100), metric=:manhattan)
        model = ABM(GridAgent{2}, space)
        x₀ = (50,50)
        add_agent!(x₀, model)
        r = 1.5
        randomwalk!(model.agents[1], model, r)
        x₁ = model.agents[1].pos
        # manhattan distance after the random step should be 1
        @test manhattan_distance(x₁, x₀, model) == 1
        # for r < 1 the agent should not move
        r = 0.5
        randomwalk!(model.agents[1], model, r)
        @test model.agents[1].pos == x₁

        space = SpaceType((100,100), metric=:manhattan)
        model = ABM(GridAgent{2}, space)
        pos = (50,50)
        add_agent!(pos, model) # agent id = 1
        # fill surrounding positions with other agents
        offsets = [(-1,0), (1,0), (0,1), (0,-1)]
        for β in offsets; add_agent!(pos.+β, model); end
        if SpaceType == GridSpaceSingle
            # agent 1 should not move since there are no available offsets
            randomwalk!(model.agents[1], model, 1)
            @test model.agents[1].pos == pos
            # the keyword ifempty should have no effect in a GridSpaceSingle
            randomwalk!(model.agents[1], model, 1; ifempty=false)
            @test model.agents[1].pos == pos
            randomwalk!(model.agents[1], model, 1; ifempty=true)
            @test model.agents[1].pos == pos
            # if agent 2 (49,50) moves, then agent 1 can only move
            # to the position that was just freed
            randomwalk!(model.agents[2], model, 1)
            randomwalk!(model.agents[1], model, 1)
            @test model.agents[1].pos == (49,50)
        elseif SpaceType == GridSpace
            # if ifempty=true (default), agent 1 should not move since there are
            # no available offsets
            randomwalk!(model.agents[1], model, 1)
            @test model.agents[1].pos == pos
            # if ifempty=false, agent 1 will move and occupy
            # the same position as one of the other agents
            randomwalk!(model.agents[1], model, 1; ifempty=false)
            @test model.agents[1].pos ≠ pos
            # 5 agents but only 4 unique positions
            unique_pos = unique([a.second.pos for a in model.agents])
            @test (length(model.agents)==5) && length(unique_pos)==4
        end
    end

end

# TODO: Test nearby_ids(r = Tuple)