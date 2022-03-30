using LightOSM
using Graphs

@testset "OpenStreetMap space" begin
    space = OpenStreetMapSpace(OSM.test_map(); network_type = :none, weight_type = :time)
    @test length(space.s) == 9753
    @test sprint(show, space) ==
          "OpenStreetMapSpace with 3353 ways and 9753 nodes"

    model = ABM(Agent10, space; rng = MersenneTwister(42))

    @test OSM.random_road_position(model) != OSM.random_road_position(model)
    intersection = random_position(model)
    @test intersection[1] == intersection[2]
    @test intersection[3] == 0.0
    ll = OSM.lonlat(intersection, model)
    @test intersection == OSM.nearest_node(ll, model)

    start_lonlat = (9.9351811, 51.5328328)
    start_i = OSM.nearest_node(start_lonlat, model)
    i_diff = sum(abs.(OSM.lonlat(start_i, model) .- start_lonlat))
    start_r = OSM.nearest_road(start_lonlat, model)
    r_diff = sum(abs.(OSM.lonlat(start_r, model) .- start_lonlat))
    @test i_diff >= r_diff

    finish_lonlat = (9.945125635913511, 51.530876112711745)
    finish_i = OSM.nearest_node(finish_lonlat, model)
    finish_r = OSM.nearest_road(finish_lonlat, model)

    add_agent!(start_r, model)
    plan_route!(model[1], finish_r, model)
    @test length(model.space.routes[1].route) == 85
    add_agent!(finish_i, model)

    @test OSM.lonlat(model[2], model) == OSM.lonlat(finish_i[1], model)
    np_lonlat = nearby_positions(model[2], model)
    @test length(np_lonlat) == 5
    @test all(OSM.lonlat(np_lonlat[1], model) .≈ (9.9451386, 51.5307792))
    
    @test OSM.latlon(model[2], model) == OSM.latlon(finish_i[1], model)
    np_latlon = nearby_positions(model[2], model)
    @test length(np_latlon) == 5
    @test all(OSM.latlon(np_latlon[1], model) .≈ (51.5307792, 9.9451386))

    @test OSM.road_length(model[1].pos, model) ≈ 0.0002591692620559716
    @test OSM.road_length(finish_r[1], finish_r[2], model) ≈ 0.00030269737299400725

    move_agent!(model[1], (start_r[2], start_r[2], 0.0), model)
    plan_route!(model[1], finish_r[1], model)
    @test length(model.space.routes[1].route) == 95

    move_agent!(model[1], start_r, model)
    plan_route!(model[1], finish_r[1], model)
    @test length(model.space.routes[1].route) == 86

    move_agent!(model[1], (start_r[2], start_r[2], 0.0), model)
    plan_route!(model[1], finish_r, model)
    @test length(model.space.routes[1].route) == 94

    move_agent!(model[2], start_r, model)
    plan_route!(model[2], finish_r[1], model)
    @test model.space.routes[1].route != model.space.routes[2].route

    plan_route!(model[2], finish_r, model)
    @test length(model.space.routes[2].route) == 85

    @test !is_stationary(model[1], model)
    move_along_route!(model[1], model, 0.01)
    @test length(model.space.routes[1].route) == 62
    move_along_route!(model[1], model, 1500)
    @test is_stationary(model[1], model)

    for i in 1:5
        s = (start_r[1:2]..., i / 5 * OSM.road_length(start_r, model))
        add_agent!(s, model)
        route = plan_route!(model[2+i], finish_r, model)
    end

    @test sort!(nearby_ids(model[6], model, 0.01)) == [2, 3, 4, 5, 7]
    @test sort!(nearby_ids(model[6].pos, model, 2.0)) == [1, 2, 3, 4, 5, 6, 7]

    # Test long moves
    move_agent!(model[1], start_i, model)
    plan_route!(model[1], finish_i, model)
    move_along_route!(model[1], model, 1e5)
    @test all(model[1].pos .≈ finish_i)
    move_agent!(model[1], start_i, model)
    plan_route!(model[1], finish_i, model; return_trip = true)
    move_along_route!(model[1], model, 1e5)
    @test OSM.identical_position(model[1].pos, start_i, model)
    @test OSM.plan_random_route!(model[1], model; limit = 100)
    @test !is_stationary(model[1], model)
    move_along_route!(model[1], model, 1e5)
    @test all(model[1].pos .!= start_i)


    # distance checks
    pos_1 = start_i[1]
    nbor = Int(outneighbors(model.space.map.graph, pos_1[1])[1])
    rl = OSM.road_length(pos_1, nbor, model)
    @test OSM.distance(pos_1, nbor, model) ≈ rl
    @test OSM.distance(pos_1, pos_1, model) == 0.
    @test OSM.distance((pos_1, nbor, 0.), (nbor, pos_1, rl), model) == 0.
    @test OSM.distance((pos_1, nbor, rl / 4), (nbor, pos_1, rl / 4), model) ≈ rl / 2
    move_agent!(model[1], (pos_1, pos_1, 0.), model)
    plan_route!(model[1], finish_i, model)
    len = sum(LightOSM.weights_from_path(
        model.space.map,
        reverse([model.space.map.index_to_node[i] for i in model.space.routes[1].route]),
    ))
    len += OSM.road_length(pos_1, model.space.routes[1].route[end], model)
    @test OSM.distance(pos_1, finish_i, model) ≈ len
end
