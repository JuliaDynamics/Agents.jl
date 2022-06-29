using Test, Agents, Random
using StableRNGs

mutable struct GridAgent2D <: AbstractAgent
    id::Int
    pos::Dims{2}
end

@testset "$(SpaceType)" for SpaceType in (GridSpace, GridSpaceSingle)
    @testset "size, dim=$D" for D in (1,3)
        dims = (fill(5, D)...,)
        for periodic in (true, false)
            space = SpaceType(dims; periodic)
            poss = positions(space)
            @test size(poss) == dims
            @test size(space) == dims
        end
    end

    @testset "positions + empty" begin
        space = SpaceType((3, 3))
        model = ABM(GridAgent2D, space)
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
            @test pos2[1].id == 1

            @test positions(model, :population) ==
                [pos_map[i] for i in [1, 2, 3, 4, 5, 6, 9, 7, 8]]
            @test length(ids_in_position(5, model)) > length(ids_in_position(7, model))
            @test_throws ErrorException positions(model, :notreal)
        end
    end

    @testset "Distances" begin
    @testset "Euclidean distance" begin
        model = ABM(GridAgent2D, SpaceType((12, 10); periodic = true))
        a = add_agent!((1.0, 6.0), model)
        b = add_agent!((11.0, 4.0), model)
        @test euclidean_distance(a, b, model) ≈ 2.82842712

        model = ABM(GridAgent2D, SpaceType((12, 10); periodic = false))
        a = add_agent!((1.0, 6.0), model)
        b = add_agent!((11.0, 4.0), model)
        @test euclidean_distance(a, b, model) ≈ 10.198039
    end
    @testset "Manhattan Distance" begin
        model = ABM(GridAgent2D, SpaceType((12, 10); metric = :manhattan, periodic = true))
        a = add_agent!((1.0, 6.0), model)
        b = add_agent!((11.0, 4.0), model)
        @test manhattan_distance(a, b, model) ≈ 4

        model = ABM(GridAgent2D, SpaceType((12, 10); metric = :manhattan, periodic = false))
        a = add_agent!((1.0, 6.0), model)
        b = add_agent!((11.0, 4.0), model)
        @test manhattan_distance(a, b, model) ≈ 12
    end
    end

    @testset "Nearby pos/ids/agents" begin
        metrics = [:euclidean, :manhattan, :chebyshev]
        periodics = [false, true]

        # All following are with r=1
        @testset "Metric=$(metric)" for metric in metrics
        @testset "periodic=$(periodic)" for periodic in periodics
            # To undersatnd where the numbers here are coming from,
            # check out the plot in the docs that shows the metrics
            model = ABM(GridAgent2D, SpaceType((5, 5); metric, periodic))
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

            genocide!(model)
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
        end
        # also test larger r

    end

end

# TODO: Test nearby_ids(r = Tuple)