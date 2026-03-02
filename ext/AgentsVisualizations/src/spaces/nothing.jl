# We need to implement plotting for a `nothing` space,
# so that the data collection GUI can work for it, even if there is
# nothing to plot for the space itself.

Agents.space_axis_limits(::Nothing) = ((nothing, nothing), (nothing, nothing))

function Agents.agentsplot!(ax, model::T, args...) where {T <: Observable{A} where {A <: ABM{<:Nothing}}}
    return nothing
end
