@testset "metrics" begin

pfinder_2d_np_m = Pathfinder{2,false}(Dict(), (10, 10), true, 0., fill(true, 10, 10), DirectDistanceMetric{2}())
pfinder_2d_np_nm = Pathfinder{2,false}(Dict(), (10, 10), false, 0., fill(true, 10, 10), DirectDistanceMetric{2}())
pfinder_2d_p_m = Pathfinder{2, true}(Dict(), (10, 10), true, 0., fill(true, 10, 10), DirectDistanceMetric{2}())
pfinder_2d_p_nm = Pathfinder{2, true}(Dict(), (10, 10), false, 0., fill(true, 10, 10), DirectDistanceMetric{2}())
hmap = fill(0, 10, 10)
hmap[:, 6] .= 100
hmap[1, 6] = 0


@test delta_cost(pfinder_2d_np_m, DirectDistanceMetric{2}(), (1, 1), (4, 6)) == 62
@test delta_cost(pfinder_2d_p_m, DirectDistanceMetric{2}(), (1, 1), (8, 6)) == 62
@test delta_cost(pfinder_2d_np_nm, DirectDistanceMetric{2}(), (1, 1), (4, 6)) == 80
@test delta_cost(pfinder_2d_p_nm, DirectDistanceMetric{2}(), (1, 1), (8, 6)) == 80

@test delta_cost(pfinder_2d_np_m, ChebyshevMetric{2}(), (1, 1), (4, 6)) == 5
@test delta_cost(pfinder_2d_p_m, ChebyshevMetric{2}(), (1, 1), (8, 6)) == 5
@test delta_cost(pfinder_2d_np_nm, ChebyshevMetric{2}(), (1, 1), (4, 6)) == 5
@test delta_cost(pfinder_2d_p_nm, ChebyshevMetric{2}(), (1, 1), (8, 6)) == 5

@test delta_cost(pfinder_2d_np_m, HeightMapMetric(hmap), (1, 1), (4, 6)) == 162
@test delta_cost(pfinder_2d_p_m, HeightMapMetric(hmap), (1, 1), (8, 6)) == 162
@test delta_cost(pfinder_2d_np_nm, HeightMapMetric(hmap), (1, 1), (4, 6)) == 180
@test delta_cost(pfinder_2d_p_nm, HeightMapMetric(hmap), (1, 1), (8, 6)) == 180
end

@testset "pathing" begin
wlk = fill(true, 7, 6)
wlk[2:7, 1] .= false
wlk[7, 3:6] .= false
wlk[[2:4; 6], 4] .= false
wlk[2:5, 5] .= false
wlk[2, 2] = false
wlk[4, 3] = false
wlk[5, 3] = false

pfinder_2d_np_m = Pathfinder{2,false}(Dict(), (7, 6), true, 0., wlk, DirectDistanceMetric{2}())
pfinder_2d_np_nm = Pathfinder{2,false}(Dict(), (7, 6), false, 0., wlk, DirectDistanceMetric{2}())
pfinder_2d_p_m = Pathfinder{2, true}(Dict(), (7, 6), true, 0., wlk, DirectDistanceMetric{2}())
pfinder_2d_p_nm = Pathfinder{2, true}(Dict(), (7, 6), false, 0., wlk, DirectDistanceMetric{2}())
end