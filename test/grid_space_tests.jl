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
            space = SpaceType(dims; periodic = true)
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

    @testset "Nearby ids/agents" begin
        @testset "Euclidean, periodic=false" begin
            grid_euclidean = ABM(GridAgent2D, SpaceType((3, 3);
                metric = :euclidean, periodic = false))
            @test collect(nearby_positions((2, 2), grid_euclidean)) ==
                [(2, 1), (1, 2), (3, 2), (2, 3)]
            @test collect(nearby_positions((1, 1), grid_euclidean)) == [(2, 1), (1, 2)]

            a = add_agent!((2, 2), grid_euclidean)
            add_agent!((3, 2), grid_euclidean)
            @test collect(nearby_ids((1, 2), grid_euclidean)) == [1]
            @test sort!(collect(nearby_ids((1, 2), grid_euclidean, 2))) == [1, 2]
            @test sort!(collect(nearby_ids((2, 2), grid_euclidean))) == [1, 2]
            @test collect(nearby_ids(a, grid_euclidean)) == [2]
        end

    end

end