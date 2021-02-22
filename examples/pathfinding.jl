using Agents

@agent Person GridAgent{2} begin end
@agent Wall GridAgent{2} begin end

space = GridSpace((10, 10); periodic = false)

heightmap = fill(0, 10, 10)
heightmap[:, 6] .= 100
heightmap[1, 6] = 0
pf = AStar(space; cost_metric = HeightMap(heightmap))

model = ABM(Union{Person,Wall}, space, pf; warn = false)

person = add_agent_pos!(Person(1, (9, 1)), model)
for i in 1:10
    for j in 1:10
        heightmap[i, j] == 100 && add_agent_pos!(Wall(nextid(model), (i, j)), model)
    end
end
set_target!(person, (9, 9), model)
agent_step!(agent, model) = move_agent!(agent, model)

using InteractiveDynamics, GLMakie
mark(a::Person) = '⚪'
mark(a::Wall) = '◼'
abm_data_exploration(model, agent_step!, dummystep; am = mark, as = 40)
