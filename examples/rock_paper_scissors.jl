# # Rock, Paper, Scissors

# Quick implementation of the Netlogo RPS example

using Agents

mutable struct Player <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    color::Symbol
end

model = ABM(
    Player,
    GridSpace((150, 150));
    properties = Dict(
        :tick => 0,
        :any_votes_changed => true,
        :change_vote_if_tied => true,
        :award_close_calls_to_loser => true,
    ),
)

for _ in 1:prod(size(model.space))
    add_agent_single!(model, rand((:red, :green, :blue, :black)))
end

function model_step!(model)
    repetitions = prod(model.space)/3

end
