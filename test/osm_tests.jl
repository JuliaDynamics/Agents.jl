@testset "OpenStreetMap space" begin
    space = OpenStreetMapSpace(TEST_MAP)
    @test length(space.edges) == 3983
    @test length(space.s) == 1799
    @test sprint(show, space) ==
          "OpenStreetMapSpace with 1456 roadways and 1799 intersections"

    Random.seed!(648)
    model = ABM(Agent10, space)

    start = osm_random_road_position(model)
    @test start == (160, 425, 16.39512622825462)
    finish = random_position(model)
    @test finish == (732, 732, 0.0)

    route = osm_plan_route(start, finish, model)
    add_agent!(start, model, route, finish)
    @test model[1].route ==
          [1037, 183, 951, 31, 30, 169, 1290, 1392, 562, 502, 373, 880, 839, 838, 1161, 731]

    osm_random_route!(model[1], model)
    @test model[1].destination == (852, 623, 3.245206244141895)

    @test !osm_is_stationary(model[1])
    add_agent!(finish, model, [], finish)
    @test osm_is_stationary(model[2])

    @test osm_road_length(155, 156, model) ≈ 156.83163771241126
    @test osm_road_length(model[1].pos, model) ≈ 23.31229481847575

    @test osm_plan_route(493, 396, model) == [493, 1624, 1002, 1003, 1406, 1418, 396]
    @test osm_plan_route((1219, 493, 5.3), 396, model) ==
          [1624, 1002, 1003, 1406, 1418, 396]
    @test osm_plan_route(493, (396, 395, 57.8), model) ==
          [493, 1624, 1002, 1003, 1406, 1418]
    @test osm_plan_route((1219, 493, 5.3), (396, 395, 57.8), model) ==
          [1624, 1002, 1003, 1406, 1418]

    @test osm_map_coordinates(model[1], model) == (-944.9545052731291, 2307.6746634446167)
    @test osm_map_coordinates(model[2], model) == (-296.67527937436853, 1228.3036909839814)

    @test model[1].pos[1] == 160
    move_agent!(model[1], model, 500.6)
    @test model[1].pos[1] == 943
    @test move_agent!(model[2], model, 50) == nothing

    for _ in 3:100
        start = osm_random_road_position(model)
        finish = osm_random_road_position(model)
        route = osm_plan_route(start, finish, model)
        add_agent!(start, model, route, finish)
    end

    @test nearby_ids(model[5], model, 50) == [33]
    @test sort!(nearby_ids(model[5], model, 300)) == [14, 33, 69]
end

