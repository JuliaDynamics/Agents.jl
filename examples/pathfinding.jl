using Agents

@agent Person GridAgent{2} begin end
@agent Wall GridAgent{2} begin end

space = GridSpace((10, 10); periodic=false)
heightmap = fill(0, 10, 10)
heightmap[:, 6] .= 100
heightmap[1, 6] = 0
props = Dict(
    :pathfinder => Pathfinder(space; cost_metric=HeightMapMetric(heightmap)),
)

model = ABM(Union{Person,Wall}, space; properties=props)

add_agent_pos!(Person(1, (1, 1)), model)
for i in 1:10
    for j in 1:10
        heightmap[i, j] == 100 && add_agent_pos!(Wall(nextid(model), (i, j)), model)
    end
end
set_target!(model[1], model.pathfinder, (9, 9))
agent_step!(agent, model) = move_agent!(agent, model, model.pathfinder)

using InteractiveDynamics, GLMakie
mark(a::Person) = '⚪'
mark(a::Wall) = '◼'
abm_data_exploration(model, agent_step!, dummystep; am=mark, as=40)
