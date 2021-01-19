@testset "OpenStreetMap space" begin
    space = OpenStreetMapSpace(TEST_MAP)
    @test length(space.edges) == 3983
    @test length(space.s) == 1799
    @test sprint(show, space) ==
          "OpenStreetMapSpace with 1456 roadways and 1799 intersections"

    model = ABM(Agent10, space)

    @test osm_random_road_position(model) != osm_random_road_position(model)
    intersection = random_position(model)
    @test intersection[1] == intersection[2]
    @test intersection[3] == 0.0

    start = (1314, 1315, 102.01607779515982)
    finish = (1374, 1374, 0.0)

    route = osm_plan_route(start, finish, model)
    add_agent!(start, model, route, finish)
    @test model[1].route == [1314, 176, 1089]

    osm_random_route!(model[1], model)
    @test model[1].destination != finish

    @test !osm_is_stationary(model[1])
    add_agent!(finish, model, [], finish)
    @test osm_is_stationary(model[2])
    @test move_agent!(model[2], model, 50) == nothing

    @test model.space.edges[20] == CartesianIndex(7, 8)
    @test osm_road_length(model.space.edges[20].I..., model) ≈ 72.39903731753334
    @test osm_road_length(model[1].pos, model) ≈ 186.0177111664528

    @test osm_plan_route(87, 396, model) == [87, 150, 1348, 270, 271, 1210, 1254, 396]
    @test osm_plan_route((1303, 87, 5.3), 396, model) ==
          [150, 1348, 270, 271, 1210, 1254, 396]
    @test osm_plan_route(87, (396, 395, 57.8), model) ==
          [87, 150, 1348, 270, 271, 1210, 1254]
    @test osm_plan_route((1303, 87, 5.3), (396, 395, 57.8), model) ==
          [150, 1348, 270, 271, 1210, 1254]

    @test osm_map_coordinates(model[1], model) == (-3879.1636699579667, -986.5761399749067)
    @test osm_map_coordinates(model[2], model) == (-4091.47751959424, -775.3195065318789)

    model = ABM(Agent10, OpenStreetMapSpace(TEST_MAP))
    start = (1314, 1315, 102.01607779515982)
    finish = (1374, 1374, 0.0)

    route = osm_plan_route(start, finish, model)
    add_agent!(start, model, route, finish)
    @test model[1].pos[1] == 1314
    move_agent!(model[1], model, 403.2)
    @test model[1].pos[1] == 176

    for i in 1:5
        s = (start[1:2]..., start[3] - i)
        route = osm_plan_route(s, finish, model)
        add_agent!(s, model, route, finish)
    end

    @test sort!(nearby_ids(model[5], model, 3)) == [2, 3, 4, 6]
    #@test sort!(nearby_ids(model[5], model, 500)) == [3, 4, 6, 7] # Currently failing...
end

import Agents.OpenStreetMapX
@testset "OSMX" begin
    start = 1315
    finish = 1374

    start_idx = 3625688657
    finish_idx = 2985292255

    map_one = OpenStreetMapX.get_map_data(TEST_MAP, use_cache = false)
    map_two = OpenStreetMapX.get_map_data(TEST_MAP, use_cache = false)

    @test start_idx == map_one.n[start]
    @test start_idx == map_two.n[start]
    @test finish_idx == map_one.n[finish]
    @test finish_idx == map_two.n[finish]

    route_one =
        OpenStreetMapX.shortest_route(map_one, map_one.n[start], map_one.n[finish])[1]
    route_two =
        OpenStreetMapX.shortest_route(map_two, map_two.n[start], map_two.n[finish])[1]
    @test route_one == route_two
    @test map(p -> getindex(map_one.v, p), route_one) == map(p -> getindex(map_two.v, p), route_two)
end
