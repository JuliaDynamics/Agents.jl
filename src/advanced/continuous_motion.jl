module ContinuousMotion
using Agents

"""
    elastic_collision!(a, b, f = nothing)
Resolve a (hypothetical) elastic collision between the two agents `a, b`.
They are assumed to be disks of equal size touching tangentially.
Their velocities (field `vel`) are adjusted for an elastic collision happening between them.
This function works only for two dimensions.
Notice that collision only happens if both disks face each other, meaning that their
velocities have angle > π/2, to avoid collision-after-collision problems.

If `f` is a `Symbol`, then the agent property `f`, e.g. `:mass`, is taken as a mass
to weight the two agents for the collision. By default no weighting happens.

One of the two agents can have infinite "mass", and then acts as an immovable object
that specularly reflects the other agent. In this case of course momentum is not
conserved, but kinetic energy is still conserved.

Example usage in [Continuous space social distancing for COVID-19](@ref).
"""
function elastic_collision!(a, b, f = nothing)
    # Do elastic collision according to
    # https://en.wikipedia.org/wiki/Elastic_collision#Two-dimensional_collision_with_two_moving_objects
    v1, v2, x1, x2 = a.vel, b.vel, a.pos, b.pos
    length(v1) ≠ 2 && error("This function works only for two dimensions.")
    r1 = x1 .- x2
    r2 = x2 .- x1
    m1, m2 = f === nothing ? (1.0, 1.0) : (getfield(a, f), getfield(b, f))
    # mass weights
    m1 == m2 == Inf && return false
    if m1 == Inf
        @assert v1 == (0, 0) "An agent with ∞ mass cannot have nonzero velocity"
        dot(r1, v2) ≤ 0 && return false
        v1 = ntuple(x -> zero(eltype(v1)), length(v1))
        f1, f2 = 0.0, 2.0
    elseif m2 == Inf
        @assert v2 == (0, 0) "An agent with ∞ mass cannot have nonzero velocity"
        dot(r2, v1) ≤ 0 && return false
        v2 = ntuple(x -> zero(eltype(v1)), length(v1))
        f1, f2 = 2.0, 0.0
    else
        # Check if disks face each other, to avoid double collisions
        !(dot(r2, v1) > 0 && dot(r2, v1) > 0) && return false
        f1 = (2m2 / (m1 + m2))
        f2 = (2m1 / (m1 + m2))
    end
    ken = norm(v1)^2 + norm(v2)^2
    dx = a.pos .- b.pos
    dv = a.vel .- b.vel
    n = norm(dx)^2
    n == 0 && return false # do nothing if they are at the same position
    a.vel = v1 .- f1 .* (dot(v1 .- v2, r1) / n) .* (r1)
    b.vel = v2 .- f2 .* (dot(v2 .- v1, r2) / n) .* (r2)
    return true
end


end
