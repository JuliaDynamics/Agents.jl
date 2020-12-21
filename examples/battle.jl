# # Battle Royal
# ![](battle.gif)
#
# This example illustrates how to leverage higher dimensions of a `GridSpace` to identify
# the distance from neighbors not just spatially, but also categorically. We'll also use
# the [`walk!`](@ref) function extensively.

# ## Rules of Engagement
# Agents wander around the map looking for opponents. When a grid space is occupied by
# two or more agents there will be a battle. With experience gained from the fight, the
# victor searches for more opponents to crush and losers scurry away defeated or possibly
# even die. This process repeats until there is a single, definitive winner.
#
# For this battle ground to exist, the following rules must be followed:
# - Agents have an experience level, starting at level 1 up to a maximum of 10.
# - Agents will walk randomly to search for opponents when none are nearby.
# - Once opponents are found, agents will (in this explicit order)
#   1. Approach the nearest worthy opponent (one with equal or ±1 experience level)
#   2. Chase down a weak opponent (with experience level -2 or fewer)
#   3. Run from a tougher opponent (with experience level +2 or higher)
# - If a strong opponent captures a weak one, they will taunt it before killing it.
# During this taunting the weaker opponent calls for help. If heard, other agents may
# choose to temporarily team up and fight the tougher opponent together for a larger
# experience boost.
# - Battles are one by weighted chance - a higher level gives an agent a larger chance of
# winning, but does not guarantee it. When a victor is chosen
#   - The difference in experience between opponents is swapped.
#   - If an agents experience reaches 0, they die.
#
# ## Model Setup

cd(@__DIR__) #src
using Random # hide
using Agents
using Plots
gr() # hide

mutable struct Fighter <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int,Int}
    has_prisoner::Bool
    capture_time::Int
    shape::Symbol #Drop this. Solely for identifying what the agent is doing at this point in time for debugging purposes
end

# As you can see, the properties of out agent are very simple.

Random.seed!(6547) # hide
model =
    ABM(Fighter, GridSpace((100, 100, 10); periodic = false); scheduler = random_activation) #NOTE: moved to non-periodic since I didn't want qualitative wrapping.

n = 0
while n != 50
    pos = (rand(1:100, 2)..., 1)
    if isempty(pos, model)
        add_agent!(pos, model, false, 0, :diamond)
        n += 1
    end
end

function closest_target(agent::Fighter, ids::Vector{Int}, model::ABM)
    if length(ids) == 1
        closest = ids[1]
    else
        close_id = argmin(map(id -> edistance(space(agent), space(model[id]), model), ids))
        closest = ids[close_id]
    end
    return model[closest]
end

# Lets say captured targets are killed after 5 cycles. Captor gains 50% of their experience.
# Captors are venerable for those 5 cycles, so anyone else can kill them and gain UP TO 50% of their experience.
function agent_step!(agent, model)
    if agent.capture_time > 0
        agent.capture_time += 1
    elseif agent.has_prisoner
        close_ids = collect(nearby_ids(agent, model, (0, 0, 10)))
        if length(close_ids) == 1
            #Taunt prisoner or kill it
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
            exploiter = rand([
                model[id]
                for
                id in close_ids if
                model[id].capture_time == 0 && model[id].has_prisoner == false
            ])
            exploiter.shape = :square
            gain = ceil(Int, level(agent) / 2)
            new_lvl = min(level(agent) + rand(1:gain), 10)
            kill_agent!(agent, model)
            move_agent!(exploiter, (space(exploiter)..., new_lvl), model)
            # Prisoner runs away in the commotion
            prisoner.shape = :utriangle
            prisoner.capture_time = 0
            walk!(prisoner, (rand(-1:1, 2)..., 0), model)
        end
    else
        origin = space(agent)
        # Find agents that have captives, they are not focused
        occupied_ids = collect(Iterators.filter(
            id -> model[id].has_prisoner,
            nearby_ids(agent, model, (7, 7, 10)),
        ))
        if !isempty(occupied_ids)
            target = space(closest_target(agent, occupied_ids, model))
            agent.shape = :pentagon
            walk!(agent, (sign.(target .- origin)..., 0), model)
        else
            # Opponents that are greatly higher in rank that the current agent
            strong_ids = collect(Iterators.filter(
                id -> level(agent) + 1 < level(model[id]),
                nearby_ids(agent, model, (5, 5, 4)),
            ))
            if !isempty(strong_ids)
                # Run away from nearest
                target = space(closest_target(agent, strong_ids, model))
                agent.shape = :utriangle
                walk!(agent, (sign.(origin .- target)..., 0), model)
            else
                worthy_ids =
                    collect(nearby_ids(agent, model, (size(model.space)[1:2]..., 1)))
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
                    weak_ids = collect(Iterators.filter(
                        id -> level(agent) - 1 > level(model[id]),
                        nearby_ids(agent, model, (10, 10, 4)),
                    ))
                    if !isempty(weak_ids)
                        # Chase down nearest
                        prisoner = closest_target(agent, weak_ids, model)
                        target = space(prisoner)
                        if origin == target
                            #Capture and taunt target
                            agent.has_prisoner = true
                            agent.shape = :vline
                            prisoner.capture_time += 1
                            prisoner.shape = :hline
                        else
                            agent.shape = :star4
                            walk!(agent, (2 .* sign.(target .- origin)..., 0), model)
                        end
                    else
                        # Abandon honour. This is the end.
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
                                # Move towards opponent
                                walk!(agent, (sign.(target .- origin)..., 0), model)
                            end
                        end
                    end
                end
            end
        end
    end

    return nothing
end

# We use a helper function `space` which allows us to invoke a number of helpful
# utilities but only operate on our spatial dimensions.

space(agent) = agent.pos[1:2]
level(agent) = agent.pos[3]

# Since our battles are only between opponents with equal, or as much as one level apart,
# the odds can be set explicitly. Stronger opponents have twice the capacity of winning a
# match.

function battle!(one::Fighter, two::Fighter, model)
    if level(one) == level(two)
        # Odds are equivalent
        one_winner = rand() < 0.5
    elseif level(one) > level(two)
        # Odds are in favor of one
        one_winner = 2 * rand() > rand()
    else
        # Odds are in favor of two
        one_winner = rand() > 2 * rand()
    end

    one_winner ? (up = one; down = two) : (up = two; down = one)

    new_lvl_up = min(level(up) + 1, 10)
    new_pos_up = clamp.(rand(-1:1, 2) .+ space(up), [1, 1], size(model.space)[1:2])
    move_agent!(up, (new_pos_up..., new_lvl_up), model)
    new_lvl_down = level(down) - 1
    if new_lvl_down == 0
        kill_agent!(down, model)
    else
        move_agent!(down, (space(down)..., new_lvl_down), model)
    end
end

# When there are only few fighters standing, the stakes are higher. Prior experience is
# paramount since there is no gain, and fights are to the death.
function showdown!(one::Fighter, two::Fighter, model)
    if level(one) == level(two)
        # Odds are equivalent
        one_winner = rand() < 0.5
    elseif level(one) > level(two)
        # Odds are in favor of one
        one_winner = level(one) - level(two) * rand() > rand()
    else
        # Odds are in favor of two
        one_winner = rand() > level(two) - level(one) * rand()
    end

    one_winner ? kill_agent!(two, model) : kill_agent!(one, model)
end

# ## Let the Battle Begin
clr(agent) = cgrad(:tab10)[level(agent)]
anim = @animate for i in 0:225
    posn = [space(model[id]) for id in by_id(model)]
    cm = [clr(model[id]) for id in by_id(model)]
    shp = [model[id].shape for id in by_id(model)]
    scatter(
        posn,
        legend = :none,
        color = cm,
        markersize = 7,
        markershape = shp,
        xlims = (-2, 103),
        ylims = (-2, 103),
        showaxis = false,
        minorgrid = true,
        ticks = (0:10:100, []),
    )
    step!(model, agent_step!, 1)
end
gif(anim, "battle.gif", fps = 10)

# Some interesting behaviours. Sometimes you see a group of diamonds chasing one triangle.
# What ends up happening here is usually a close pair that wishes to fight gets caught
# out by the weaker one of the two running away from an even stronger opponent. Problem
# is that this stronger opponent is chasing the stronger of the pair, but since the
# weakest of the pair is still closer to the newcomer, there is a stalemate.
# This is usually resolved by hitting a boundary or other opponents.
