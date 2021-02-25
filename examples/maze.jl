using Agents
using FileIO

maze = map(x->x.r > 0, load("examples/maze.bmp"))

@agent Walker GridAgent{2} begin end
@agent Wall GridAgent{2} begin end

function initalize_model()
    space = GridSpace((41,41); periodic = false)
    pathfinder = AStar(space; walkable = maze)
    model = ABM(Union{Walker,Wall}, space, pathfinder; warn=false)
    walker = Walker(1, (1,4))
    add_agent_pos!(walker, model)
    set_target!(walker, (41, 32), model)

    for i in 1:41, j in 1:41
        maze[i, j] || add_agent_pos!(Wall(nextid(model), (i, j)), model)
    end
    return model
end

agent_step!(agent, model) = move_agent!(agent, model)

using InteractiveDynamics, GLMakie

color(a::Wall) = :black
color(a::Walker) = :red
mark(a::Wall) = '⬛'
mark(a::Walker) = '⬤'

model = initalize_model()

abm_play(model, agent_step!, dummystep; ac=color, am=mark)