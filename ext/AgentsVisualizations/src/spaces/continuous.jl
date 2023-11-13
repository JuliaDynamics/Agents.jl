"Get correct axis limits for `ContinuousSpace` models."
function get_axis_limits!(model<:ABM{S::Agents.ContinuousSpace})
    e = abmspace(model).extent
    o = zero.(e)
    return o, e
end


## API functions for lifting

agents_space_dimensionality(::ContinuousSpace{D}) where {D} = D
