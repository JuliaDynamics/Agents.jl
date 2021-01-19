@testset "OpenStreetMap space" begin
    space = OpenStreetMapSpace(TEST_MAP)
    @test length(space.edges) == 3983
    @test length(space.s) == 1799
    @test sprint(show, space) ==
          "OpenStreetMapSpace with 1456 roadways and 1799 intersections"

    Random.seed!(678)
    model = ABM(Agent10, space)

    start = osm_random_road_position(model)
    @test start == (1314, 1315, 102.01607779515982)
    finish = random_position(model)
    @test finish == (1374, 1374, 0.0)

    route = osm_plan_route(start, finish, model)
    add_agent!(start, model, route, finish)
    @test model[1].route ==
            [1314, 176, 1089]

    osm_random_route!(model[1], model)
    @test model[1].destination == (1421, 399, 44.14795349153319)

    @test !osm_is_stationary(model[1])
    add_agent!(finish, model, [], finish)
    @test osm_is_stationary(model[2])

    @test osm_road_length(901, 2, model) ≈ 42.48689349620165
    @test osm_road_length(model[1].pos, model) ≈ 186.0177111664528

    @test osm_plan_route(87, 396, model) == [87, 150, 1348, 270, 271, 1210, 1254, 396]
    @test osm_plan_route((1303, 87, 5.3), 396, model) ==[150, 1348, 270, 271, 1210, 1254, 396]
    @test osm_plan_route(87, (396, 395, 57.8), model) ==  [87, 150, 1348, 270, 271, 1210, 1254]
    @test osm_plan_route((1303, 87, 5.3), (396, 395, 57.8), model) == [150, 1348, 270, 271, 1210, 1254]

    @test osm_map_coordinates(model[1], model) == (-3879.1636699579667, -986.5761399749067)
    @test osm_map_coordinates(model[2], model) == (-4091.47751959424, -775.3195065318789)

    @test model[1].pos[1] == 1314
    move_agent!(model[1], model, 500.6)
    @test model[1].pos[1] == 625
    @test move_agent!(model[2], model, 50) == nothing

    for _ in 3:100
        start = osm_random_road_position(model)
        finish = osm_random_road_position(model)
        route = osm_plan_route(start, finish, model)
        add_agent!(start, model, route, finish)
    end

    @test sort!(nearby_ids(model[81], model, 400)) == [33, 65]
    @test sort!(nearby_ids(model[81], model, 600)) == [15, 33, 54, 65, 75, 98]
end

