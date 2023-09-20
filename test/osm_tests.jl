using Test, Agents, Random
using Agents.Graphs
using StableRNGs

@agent struct AgentOSM(OSMAgent)
end

@testset "OpenStreetMap space" begin
    goettingen = OSM.test_map()
    space = OpenStreetMapSpace(goettingen; network_type = :none, weight_type = :time)
    @test length(space.s) == 9753
    @test sprint(show, space) ==
          "OpenStreetMapSpace with 3353 ways and 9753 nodes"

    model = ABM(AgentOSM, space; rng = StableRNG(42))

    start_lonlat = (9.9351811, 51.5328328)
    start_intersection = OSM.nearest_node(start_lonlat, model)
    start_road = OSM.nearest_road(start_lonlat, model)
    finish_lonlat = (9.945125635913511, 51.530876112711745)
    finish_intersection = OSM.nearest_node(finish_lonlat, model)
    finish_road = OSM.nearest_road(finish_lonlat, model)

    @testset "Obtaining positions" begin
        road_pos = OSM.random_road_position(model)
        @test road_pos[1] ≠ road_pos[2]
        @test road_pos[3] > 0

        intersection = random_position(model)
        @test intersection[1] == intersection[2]
        @test intersection[3] == 0.0

        ll = OSM.lonlat(intersection, model)
        @test intersection == OSM.nearest_node(ll, model)
        # known from geography:
        lon, lat = ll
        @test 9.9 < lon < 10.0
        @test 51.525 < lat < 51.545

        # Test that finding nearest nodes works, and that road version is closer
        intersection_diff = maximum(abs.(OSM.lonlat(start_intersection, model) .- start_lonlat))
        start_road = OSM.nearest_road(start_lonlat, model)
        road_diff = maximum(abs.(OSM.lonlat(start_road, model) .- start_lonlat))
        @test intersection_diff < 0.1 # 0.1 degrees is max degree distance for goettingen
        @test road_diff < 0.1
        @test intersection_diff > road_diff
    end

    @testset "Route planning" begin
        add_agent!(start_road, model)
        plan_route!(model[1], finish_road, model)
        @test length(abmspace(model).routes[1].route) == 85

        add_agent!(finish_intersection, model)

        @test OSM.lonlat(model[2], model) == OSM.lonlat(finish_intersection[1], model)
        np_lonlat = nearby_positions(model[2], model)
        @test length(np_lonlat) == 5
        @test all(OSM.lonlat(np_lonlat[1], model) .≈ (9.9451386, 51.5307792))

        @test OSM.latlon(model[2], model) == OSM.latlon(finish_intersection[1], model)
        np_latlon = nearby_positions(model[2], model)
        @test length(np_latlon) == 5
        @test all(OSM.latlon(np_latlon[1], model) .≈ (51.5307792, 9.9451386))

        @test OSM.road_length(model[1].pos, model) ≈ 0.0002591692620559716
        @test OSM.road_length(finish_road[1], finish_road[2], model) ≈ 0.00030269737299400725
    end

    @testset "Moving along routes" begin
        move_agent!(model[1], (start_road[2], start_road[2], 0.0), model)
        plan_route!(model[1], finish_road[1], model)
        @test length(abmspace(model).routes[1].route) == 95

        move_agent!(model[1], start_road, model)
        plan_route!(model[1], finish_road[1], model)
        @test length(abmspace(model).routes[1].route) == 86

        move_agent!(model[1], (start_road[2], start_road[2], 0.0), model)
        plan_route!(model[1], finish_road, model)
        @test length(abmspace(model).routes[1].route) == 94

        move_agent!(model[2], start_road, model)
        plan_route!(model[2], finish_road[1], model)
        @test abmspace(model).routes[1].route != abmspace(model).routes[2].route

        plan_route!(model[2], finish_road, model)
        @test length(abmspace(model).routes[2].route) == 85

        @test !is_stationary(model[1], model)
        move_along_route!(model[1], model, 0.01)
        @test length(abmspace(model).routes[1].route) == 62
        move_along_route!(model[1], model, 1500)
        @test is_stationary(model[1], model)
    end

    @testset "Nearby agents" begin
        for i in 1:5
            s = (start_road[1:2]..., i / 5 * OSM.road_length(start_road, model))
            add_agent!(s, model)
            route = plan_route!(model[2+i], finish_road, model)
        end

        @test sort!(nearby_ids(model[6], model, 0.01)) == [2, 3, 4, 5, 7]
        @test sort!(nearby_ids(model[6].pos, model, 2.0)) == [1, 2, 3, 4, 5, 6, 7]
    end

    @testset "Long moves" begin
        move_agent!(model[1], start_intersection, model)
        plan_route!(model[1], finish_intersection, model)
        move_along_route!(model[1], model, 1e5)
        @test all(model[1].pos .≈ finish_intersection)
        move_agent!(model[1], start_intersection, model)
        plan_route!(model[1], finish_intersection, model; return_trip = true)
        move_along_route!(model[1], model, 1e5)
        @test OSM.same_position(model[1].pos, start_intersection, model)
        @test OSM.plan_random_route!(model[1], model; limit = 100)
        @test !is_stationary(model[1], model)
        move_along_route!(model[1], model, 1e5)
        @test all(model[1].pos .!= start_intersection)
    end

    @testset "Distances, road/route lengths" begin
        pos_1 = start_intersection[1]
        nbor = Int(outneighbors(abmspace(model).map.graph, pos_1[1])[1])
        rl = OSM.road_length(pos_1, nbor, model)
        @test OSM.distance(pos_1, nbor, model) ≈ rl
        @test OSM.distance(pos_1, pos_1, model) == 0.
        @test OSM.distance((pos_1, nbor, 0.0), (nbor, pos_1, rl), model) == 0.0
        @test OSM.distance((pos_1, nbor, rl/4), (nbor, pos_1, rl/4), model) ≈ rl/2
        move_agent!(model[1], (pos_1, pos_1, 0.0), model)
        plan_route!(model[1], finish_intersection, model)
        len = sum(OSM.LightOSM.weights_from_path(
            abmspace(model).map,
            reverse([abmspace(model).map.index_to_node[i] for i in abmspace(model).routes[1].route]),
        ))
        len += OSM.road_length(pos_1, abmspace(model).routes[1].route[end], model)
        @test OSM.distance(pos_1, finish_intersection, model) ≈ len
        @test OSM.route_length(model[1], model) ≈ len
    end
end
