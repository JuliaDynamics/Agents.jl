@testset "mutable graph" begin

g = complete_digraph(5)
abm = ABM(Agent5, GraphSpace(g))
for n in 1:5
    for _ in 1:5
        add_agent!(n, abm, rand(abm.rng))
    end
end
@test nv(abm) == 5
@test abm.space.s[1] == 1:5
@test abm.space.s[2] == 6:10

rem_node!(abm, 2)
@test nv(abm) == 4
@test nagents(abm) == 20
@test abm.space.s[2] == 21:25
@test length(abm.space.s) == 4

n = add_node!(abm)
@test n == 5
@test length(abm.space.s) == 5
@test nv(abm) == 5
add_edge!(abm, n, 2)


a = add_agent!(n, abm, rand(abm.rng))
ids = nearby_ids(a, abm)
@test ids == 21:25

model = ABM(Agent5, GraphSpace(SimpleGraph()))
@test_throws ArgumentError add_agent!(model, rand(model.rng))
add_node!(model)
@test nv(model) == 1
@test add_edge!(model, 1, 2) == false
add_node!(model)
@test add_edge!(model, 1, 2) == true

end
