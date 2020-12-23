# # Voting

# Quick implementation of the Netlogo Voting example

using Agents

mutable struct Voter <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    vote::Bool
    total::Int
end

model = ABM(
    Voter,
    GridSpace((10, 10));
    properties = Dict(
        :tick => 0,
        :any_votes_changed => true,
        :change_vote_if_tied => true,
        :award_close_calls_to_loser => true,
    ),
)

for _ in 1:prod(size(model.space))
    add_agent_single!(model, rand(Bool), 0)
end

function model_step!(model)
    votes_changed = false
    for a in allagents(model)
        a.total = sum(v.vote for v in nearby_agents(a, model))
    end
    for a in allagents(model)
        previous_vote = a.vote
        if a.total > 5
            a.vote = true
        elseif a.total < 3
            a.vote = false
        elseif a.total == 4 && model.change_vote_if_tied
            a.vote = !a.vote
        elseif a.total == 5
            a.vote = model.award_close_calls_to_loser ? false : true
        elseif a.total == 3
            a.vote = model.award_close_calls_to_loser ? true : false
        end

        if a.vote != previous_vote
            votes_changed = true
        end
    end
    model.any_votes_changed = votes_changed
    model.tick += 1
end

when(model, s) = !model.any_votes_changed

run!(model, dummystep, model_step!, when)

