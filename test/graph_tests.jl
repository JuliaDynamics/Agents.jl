@testset "mutable graph" begin

    g = complete_digraph(5)
    abm = ABM(Agent5, GraphSpace(g))
    for n in 1:5
        for _ in 1:5
            add_agent!(n, abm, rand(abm.rng))
        end
    end
    @test nv(abm) == 5
    ids_in_position(1, abm) == 1:5
    ids_in_position(2, abm) == 6:10

    rem_vertex!(abm, 2)
    @test nv(abm) == 4
    @test nagents(abm) == 20
    # Last node became 2nd node (swapped places as per Graphs.jl)
    @test ids_in_position(2, abm) == 21:25
    @test nv(abm) == 4

    n = add_vertex!(abm)
    @test n == 5
    @test nv(abm) == 5

    add_edge!(abm, n, 2)
    a = add_agent!(n, abm, rand(abm.rng))
    ids = nearby_ids(a, abm)
    @test sort(ids) == 21:25


    rem_edge!(abm, n, 2)
    ids = nearby_ids(a, abm)
    @test isempty(ids)

    abm = ABM(Agent5, GraphSpace(SimpleGraph()))
    @test_throws ArgumentError add_agent!(abm, rand(abm.rng))
    add_vertex!(abm)
    @test nv(abm) == 1
    @test add_edge!(abm, 1, 2) == false
    add_vertex!(abm)
    @test add_edge!(abm, 1, 2) == true

end
