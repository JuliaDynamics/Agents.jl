# TODO: This test file needs a complete re-write...

@testset "Space" begin
    @testset "Graphs" begin
        model = ABM(Agent5, GraphSpace(path_graph(5)), warn_deprecation = false)
        @test Agents.nv(model) == 5
        @test Agents.ne(model) == 4
    end

    @testset "Nearby Agents" begin
        undirected = ABM(Agent5, GraphSpace(path_graph(5)), warn_deprecation = false)
        @test nearby_positions(3, undirected) == [2, 4]
        @test nearby_positions(1, undirected) == [2]
        @test nearby_positions(5, undirected) == [4]
        @test sort!(nearby_positions(5, undirected, 2)) == [3, 4]
        @test sort!(nearby_positions(3, undirected, 2)) == [1, 2, 4, 5]
        @test nearby_positions(3, undirected; neighbor_type = :out) ==
              nearby_positions(3, undirected; neighbor_type = :in) ==
              nearby_positions(3, undirected; neighbor_type = :all) ==
              nearby_positions(3, undirected; neighbor_type = :default)
        add_agent!(1, undirected, rand(abmrng(undirected)))
        agent = add_agent!(2, undirected, rand(abmrng(undirected)))
        add_agent!(3, undirected, rand(abmrng(undirected)))
        @test sort!(nearby_positions(agent, undirected)) == [1, 3]
        # We expect id 2 to be included for a grid based search
        @test sort!(collect(nearby_ids(2, undirected))) == [1, 2, 3]
        # But to be excluded if we are looking around it.
        @test sort!(collect(nearby_ids(undirected[2], undirected))) == [1, 3]

        directed = ABM(Agent5, GraphSpace(path_digraph(5)), warn_deprecation = false)
        @test nearby_positions(3, directed) == [4]
        @test nearby_positions(1, directed) == [2]
        @test nearby_positions(5, directed) == []
        @test nearby_positions(3, directed; neighbor_type = :default) ==
              nearby_positions(3, directed)
        @test nearby_positions(3, directed; neighbor_type = :in) == [2]
        @test nearby_positions(3, directed; neighbor_type = :out) == [4]
        @test sort!(nearby_positions(3, directed; neighbor_type = :all)) == [2, 4]
        add_agent!(1, directed, rand(abmrng(directed)))
        add_agent!(2, directed, rand(abmrng(directed)))
        add_agent!(3, directed, rand(abmrng(directed)))
        @test sort!(nearby_ids(2, directed)) == [2, 3]
        @test sort!(nearby_ids(2, directed; neighbor_type = :in)) == [1, 2]
        @test sort!(nearby_ids(2, directed; neighbor_type = :all)) == [1, 2, 3]
        @test collect(nearby_ids(directed[2], directed)) == [3]
        @test collect(nearby_ids(directed[2], directed; neighbor_type = :in)) == [1]
        @test sort!(collect(nearby_ids(directed[2], directed; neighbor_type = :all))) ==
              [1, 3]




###################################################################################
# Continuous space

    end

    @agent struct Agent3D(GridAgent{3})
        weight::Float64
    end

    @agent struct Agent63(ContinuousAgent{3,Float64})
        weight::Float64
    end

end
