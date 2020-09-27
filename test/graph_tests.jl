@testset "mutable graph" begin

g = complete_digraph(5)
abm = ABM(Agent5, GraphSpace(g))
for n in 1:5
    for _ in 1:5
        add_agent!(n, abm, rand())
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


a = add_agent!(n, abm, rand())
ids = nearby_ids(a, abm)
@test ids == 21:25

end
