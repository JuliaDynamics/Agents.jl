@testset "OpenStreetMap space" begin
    space = OpenStreetMapSpace(TEST_MAP)
    @test length(space.s) == 1799
    @test sprint(show, space) ==
          "OpenStreetMapSpace with 1456 roadways and 1799 intersections"

    Random.seed!(689)
    model = ABM(Agent10, space)

    @test osm_random_road_position(model) != osm_random_road_position(model)
    intersection = random_position(model)
    @test intersection[1] == intersection[2]
    @test intersection[3] == 0.0
    ll = osm_latlon(intersection, model)
    @test intersection == osm_intersection(ll, model)

    start_latlon = (39.534773980413505, -119.78937575923226)
    start_i = osm_intersection(start_latlon, model)
    i_diff = sum(abs.(osm_latlon(start_i, model) .- start_latlon))
    start_r = osm_road(start_latlon, model)
    r_diff = sum(abs.(osm_latlon(start_r, model) .- start_latlon))
    @test i_diff > r_diff

    finish_latlon = (39.52530416953533, -119.76949287425508)
    finish_i = osm_intersection(finish_latlon, model)
    finish_r = osm_road(finish_latlon, model)

    route = osm_plan_route(start_r, finish_r, model)
    @test length(route) == 20
    add_agent!(start_r, model, route, finish_r)
    add_agent!(finish_i, model, [], finish_i)

    @test osm_latlon(model[2], model) == osm_latlon(finish_i[1], model)
    np = nearby_positions(model[2], model)
    @test length(np) == 3
    @test osm_latlon(np[1], model) == (39.5259267, -119.76681090000002)

    rand_road = osm_random_road_position(model)
    rand_intersection = random_position(model)
    rand_route = osm_plan_route(rand_road, rand_intersection, model; return_trip = true)
    @test length(rand_route) == 18

    @test osm_road_length(model[1].pos, model) ≈ 106.49016546202557
    @test osm_road_length(finish_r[1], finish_r[2], model) ≈ 395.8120895006937

    @test length(osm_plan_route(start_r[2], finish_r[1], model)) == 22
    @test length(osm_plan_route(start_r, finish_r[1], model)) == 21
    @test length(osm_plan_route(start_r[2], finish_r, model)) == 21
    @test osm_plan_route(start_r, finish_r[1], model) !=
          osm_plan_route(start_r[2], finish_r, model)
    @test length(osm_plan_route(start_r, finish_r, model)) == 20

    @test osm_map_coordinates(model[1], model) == (-2904.337825035879, 1444.5549163962387)
    @test osm_map_coordinates(model[2], model) == (-1475.8022717621393, 461.34058791100955)

    @test !osm_is_stationary(model[1])
    move_agent!(model[1], model, 403.2)
    @test length(model[1].route) == 16
    move_agent!(model[1], model, 1500)
    @test isempty(model[1].route)
    @test !osm_is_stationary(model[1])
    move_agent!(model[1], model, 200)
    @test !osm_is_stationary(model[1])
    move_agent!(model[1], model, 200)
    @test !osm_is_stationary(model[1])
    move_agent!(model[1], model, 200)
    @test osm_is_stationary(model[1])

    @test osm_is_stationary(model[2])
    @test move_agent!(model[2], model, 50) === nothing

    add_agent!(start_r, model, route, finish_r)
    osm_random_route!(model[3], model)
    @test model[3].destination != finish_r
    move_agent!(model[3], model, 100.0)

    for i in 1:5
        s = (start_r[1:2]..., start_r[3] - i)
        route = osm_plan_route(s, finish_r, model)
        add_agent!(s, model, route, finish_r)
    end

    @test sort!(nearby_ids(model[6], model, 2)) == [4, 5, 7, 8]
    @test sort!(nearby_ids(model[6], model, 800.0)) == [3, 4, 5, 7, 8]
end

