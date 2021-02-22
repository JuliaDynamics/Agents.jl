mutable struct Fighter <: AbstractAgent
    id::Int
    pos::Dims{3}
    has_prisoner::Bool
    capture_time::Int
    shape::Symbol
end

"""
```julia
battle(; fighters = 50)
```
Same as in [Battle Royale](@ref).
"""
function battle(; fighters = 50)
    model = ABM(
        Fighter,
        GridSpace((100, 100, 10); periodic = false);
        scheduler = random_activation,
    )

    n = 0
    while n != fighters
        pos = (rand(model.rng, 1:100, 2)..., 1) # Start at level 1
        if isempty(pos, model)
            add_agent!(pos, model, false, 0, :diamond)
            n += 1
        end
    end

    return model, battle_agent_step!, dummystep
end

space(agent) = agent.pos[1:2]
level(agent) = agent.pos[3]

function closest_target(agent::Fighter, ids::Vector{Int}, model::ABM)
    if length(ids) == 1
        closest = ids[1]
    else
        close_id = argmin(map(id -> edistance(space(agent), space(model[id]), model), ids))
        closest = ids[close_id]
    end
    return model[closest]
end

function battle!(one::Fighter, two::Fighter, model)
    if level(one) == level(two)
        # Odds are equivalent
        one_winner = rand(model.rng) < 0.5
    elseif level(one) > level(two)
        # Odds are in favor of one
        one_winner = 2 * rand(model.rng) > rand(model.rng)
    else
        # Odds are in favor of two
        one_winner = rand(model.rng) > 2 * rand(model.rng)
    end

    one_winner ? (up = one; down = two) : (up = two; down = one)

    new_lvl_up = min(level(up) + 1, 10)
    new_pos_up = clamp.(rand(model.rng, -1:1, 2) .+ space(up), [1, 1], size(model.space)[1:2])
    move_agent!(up, (new_pos_up..., new_lvl_up), model)
    new_lvl_down = level(down) - 1
    if new_lvl_down == 0
        kill_agent!(down, model)
    else
        move_agent!(down, (space(down)..., new_lvl_down), model)
    end
end

function captor_behavior!(agent, model)
    close_ids = collect(nearby_ids(agent, model, (0, 0, 10)))
    if length(close_ids) == 1
        # Taunt prisoner or kill it
        prisoner = model[close_ids[1]]
        if prisoner.capture_time > 10
            agent.shape = :square
            gain = ceil(Int, level(prisoner) / 2)
            new_lvl = min(level(agent) + gain, 10)
            kill_agent!(prisoner, model)
            agent.has_prisoner = false
            move_agent!(agent, (space(agent)..., new_lvl), model)
        end
    else
        # Someone is here to kill the captor. Could be more than one opponent
        prisoner = [model[id] for id in close_ids if model[id].capture_time > 0][1]
        exploiter = rand(model.rng, [
            model[id]
            for
            id in close_ids if
            model[id].capture_time == 0 && model[id].has_prisoner == false
        ])
        exploiter.shape = :square
        gain = ceil(Int, level(agent) / 2)
        new_lvl = min(level(agent) + rand(model.rng, 1:gain), 10)
        kill_agent!(agent, model)
        move_agent!(exploiter, (space(exploiter)..., new_lvl), model)
        # Prisoner runs away in the commotion
        prisoner.shape = :utriangle
        prisoner.capture_time = 0
        walk!(prisoner, (rand(model.rng, -1:1, 2)..., 0), model)
    end
end

function endgame!(agent, model)
    origin = space(agent)
    end_ids = collect(Iterators.filter(
        id -> model[id].shape == :circle && id != agent.id,
        allids(model),
    ))
    agent.shape = :circle
    if !isempty(end_ids)
        opponent = closest_target(agent, end_ids, model)
        target = space(opponent)
        if origin == target
            # Battle
            agent.shape = :square
            opponent.shape = :square
            showdown!(agent, opponent, model)
        else
            walk!(agent, (sign.(target .- origin)..., 0), model)
        end
    end
end

function showdown!(one::Fighter, two::Fighter, model)
    if level(one) == level(two)
        # Odds are equivalent
        one_winner = rand(model.rng) < 0.5
    elseif level(one) > level(two)
        # Odds are in favor of one
        one_winner = level(one) - level(two) * rand(model.rng) > rand(model.rng)
    else
        # Odds are in favor of two
        one_winner = rand(model.rng) > level(two) - level(one) * rand(model.rng)
    end

    one_winner ? kill_agent!(two, model) : kill_agent!(one, model)
end

function battle_agent_step!(agent, model)
    if agent.capture_time > 0
        # Captured agents are powerless, but we need to keep track of how long
        # they have been in this state
        agent.capture_time += 1
    elseif agent.has_prisoner
        captor_behavior!(agent, model)
    else
        origin = space(agent)
        # Find agents that have captives, they are not focused
        occupied_ids = collect(Iterators.filter(
            id -> model[id].has_prisoner,
            nearby_ids(agent, model, (7, 7, 10)),
        ))
        if !isempty(occupied_ids)
            # Sneak up behind them
            target = space(closest_target(agent, occupied_ids, model))
            agent.shape = :pentagon
            walk!(agent, (sign.(target .- origin)..., 0), model)
        else
            # Opponents that are greatly higher in rank that the current agent
            strong_ids = collect(nearby_ids(agent, model, [(1, -5:5), (2, -5:5), (3, 2:4)]))
            if !isempty(strong_ids)
                # Run away from nearest
                target = space(closest_target(agent, strong_ids, model))
                agent.shape = :utriangle
                walk!(agent, (sign.(origin .- target)..., 0), model)
            else
                # There are no distractions. Search for the closest worthy opponent
                worthy_ids = collect(nearby_ids(agent, model, [(3, -1:1)]))
                if !isempty(worthy_ids)
                    opponent = closest_target(agent, worthy_ids, model)
                    target = space(opponent)
                    if origin == target
                        # Battle
                        agent.shape = :square
                        opponent.shape = :square
                        battle!(agent, opponent, model)
                    else
                        # Move towards worthy opponent
                        agent.shape = :diamond
                        walk!(agent, (sign.(target .- origin)..., 0), model)
                    end
                else
                    # Find any weak targets in the vicinity
                    weak_ids = collect(nearby_ids(
                        agent,
                        model,
                        [(1, -10:10), (2, -10:10), (3, -4:-2)],
                    ))
                    if !isempty(weak_ids)
                        prisoner = closest_target(agent, weak_ids, model)
                        target = space(prisoner)
                        if origin == target
                            #Capture and taunt target
                            agent.has_prisoner = true
                            agent.shape = :vline
                            prisoner.capture_time += 1
                            prisoner.shape = :hline
                        else
                            # Chase down nearest (can move 2 steps at a time!)
                            agent.shape = :star4
                            walk!(agent, (2 .* sign.(target .- origin)..., 0), model)
                        end
                    else
                        # Abandon honour. This is the end
                        endgame!(agent, model)
                    end
                end
            end
        end
    end

    return nothing
end
