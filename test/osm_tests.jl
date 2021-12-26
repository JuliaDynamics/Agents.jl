using LightOSM

@testset "OpenStreetMap space" begin
    space = OpenStreetMapSpace(OSM.test_map())
    @test length(space.s) == 20521
    @test sprint(show, space) ==
          "OpenStreetMapSpace with 4393 ways and 20521 nodes"

    Random.seed!(689)
    model = ABM(Agent10, space)

    @test OSM.random_road_position(model) != OSM.random_road_position(model)
    intersection = random_position(model)
    @test intersection[1] == intersection[2]
    @test intersection[3] == 0.0
    ll = OSM.latlon(intersection, model)
    @test intersection == OSM.intersection(ll, model)

    start_latlon = (51.5328328, 9.9351811)
    start_i = OSM.intersection(start_latlon, model)
    i_diff = sum(abs.(OSM.latlon(start_i, model) .- start_latlon))
    start_r = OSM.road(start_latlon, model)
    r_diff = sum(abs.(OSM.latlon(start_r, model) .- start_latlon))
    @test i_diff >= r_diff

    finish_latlon = (51.530876112711745, 9.945125635913511)
    finish_i = OSM.intersection(finish_latlon, model)
    finish_r = OSM.road(finish_latlon, model)

    add_agent!(start_r, model)
    OSM.plan_route!(model[1], finish_r, model)
    @test length(model.space.routes[1].route) == 74
    add_agent!(finish_i, model)

    @test OSM.latlon(model[2], model) == OSM.latlon(finish_i[1], model)
    np = nearby_positions(model[2], model)
    @test length(np) == 4
    @test all(OSM.latlon(np[1], model) .≈ (51.5308349, 9.9449474))

    rand_road = OSM.random_road_position(model)
    rand_intersection = random_position(model)
    move_agent!(model[2], rand_road, model)
    OSM.plan_route!(model[2], rand_intersection, model; return_trip = true)
    @test length(model.space.routes[2].route) == 357

    @test OSM.road_length(model[1].pos, model) ≈ 0.00011942893648990791
    @test OSM.road_length(finish_r[1], finish_r[2], model) ≈ 0.00030269737299400725

    move_agent!(model[1], (start_r[2], start_r[2], 0.0), model)
    OSM.plan_route!(model[1], finish_r[1], model)
    @test length(model.space.routes[1].route) == 71

    move_agent!(model[1], start_r, model)
    OSM.plan_route!(model[1], finish_r[1], model)
    @test length(model.space.routes[1].route) == 73

    move_agent!(model[1], (start_r[2], start_r[2], 0.0), model)
    OSM.plan_route!(model[1], finish_r, model)
    @test length(model.space.routes[1].route) == 72

    move_agent!(model[2], start_r, model)
    OSM.plan_route!(model[2], finish_r[1], model)
    @test model.space.routes[1].route != model.space.routes[2].route

    OSM.plan_route!(model[2], finish_r, model)
    @test length(model.space.routes[2].route) == 74

    @test !is_stationary(model[1], model)
    move_along_route!(model[1], model, 0.01)
    @test length(model.space.routes[1].route) == 53
    move_along_route!(model[1], model, 1500)
    @test is_stationary(model[1], model)

    for i in 1:5
        s = (start_r[1:2]..., i / 5 * OSM.road_length(start_r, model))
        add_agent!(s, model)
        route = OSM.plan_route!(model[2+i], finish_r, model)
    end

    @test sort!(nearby_ids(model[6], model, 0.01)) == [2, 3, 4, 5, 7]
    @test sort!(nearby_ids(model[6].pos, model, 2.0)) == [1, 2, 3, 4, 5, 6, 7]

    # Test long moves
    start = random_position(model)
    finish = OSM.random_road_position(model)
    move_agent!(model[1], start, model)
    OSM.plan_route!(model[1], finish, model)
    move_along_route!(model[1], model, 10^5)
    @test all(model[1].pos .≈ finish)
    move_agent!(model[1], start, model)
    OSM.plan_route!(model[1], finish, model; return_trip = true)
    move_along_route!(model[1], model, 10^5)
    @test all(model[1].pos .≈ start)
end
