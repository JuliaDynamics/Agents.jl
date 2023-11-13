"Get correct axis limits for `AbstractGridSpace` models."
function get_axis_limits!(model<:ABM{S::Agents.AbstractGridSpace})
    e = size(abmspace(model)) .+ 0.5
    o = zero.(e) .+ 0.5
    return o, e
end

## API functions for lifting

agents_space_dimensionality(::AbstractGridSpace{D}) where {D} = D
