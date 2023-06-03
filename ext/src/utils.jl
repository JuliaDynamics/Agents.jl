export subscript, superscript
export record_interaction
export rotate2D, scale, Polygon, Point2f

##########################################################################################
# Check/get/set
##########################################################################################

"""
    has_key(p, key)
Check if `p` has given key. For `AbstractDict` this is `haskey`,
for anything else it is `hasproperty`.
    has_key(p, keys...)
When given multiple keys, `has_key` is called recursively, i.e.
`has_key(p, key1, key2) = has_key(has_key(p, key1), key2)` and so on.
"""
has_key(p, keys...) = has_key(has_key(p, keys[1]), Base.tail(keys)...)
has_key(p::AbstractDict, key) = haskey(p, key)
has_key(p, key) = hasproperty(p, key)

"""
    get_value(p, key)
Retrieve value of `p` with given key. For `AbstractDict` this is `getindex`,
for anything else it is `getproperty`.
    get_value(p, keys...)
When given multiple keys, `get_value` is called recursively, i.e.
`get_value(p, key1, key2) = get_value(get_value(p, key1), key2)` and so on.
For example, if `p, p.k1` are `NamedTuple`s then
`get_value(p, k1, k2) == p.k1.k2`.

"""
get_value(p, keys...) = get_value(get_value(p, keys[1]), Base.tail(keys)...)
get_value(p::AbstractDict, key) = getindex(p, key)
get_value(p, key) = getproperty(p, key)

"""
    set_value!(p, key, val)
Set `key` of `p` to `val`. For `AbstractDict` this is `p[key] = val`,
for anything else it is `setproperty`. Changing the values of `NamedTuple`s is impossible.
"""
set_value!(p::AbstractDict, key, val) = (p[key] = val)
set_value!(p::NamedTuple, key, val) = error("""
    Immutable struct of type NamedTuple cannot be changed.
    Please use a mutable container to interactively change the model properties.""")
set_value!(p, key, val) = setproperty!(p, key, val)

##########################################################################################
# Little helpers
##########################################################################################

"""
    record_interaction(file, figure; framerate = 30, total_time = 10)
Start recording whatever interaction is happening on some `figure` into a video
output in `file` (recommended to end in `".mp4"`).

## Keywords
* `framerate = 30`
* `total_time = 10`: Time to record for, in seconds
* `sleep_time = 1`: Time to call `sleep()` before starting to save.
"""
function record_interaction(file, figure;
        framerate = 30, total_time = 10, sleep_time = 1,
    )
    ispath(dirname(file)) || mkpath(dirname(file))
    sleep(sleep_time)
    framen = framerate*total_time
    record(figure, file; framerate) do io
        for i = 1:framen
            sleep(1/framerate)
            recordframe!(io)
        end
    end
    return
end
record_interaction(figure::Figure, file; kwargs...) =
record_interaction(file, figure; kwargs...)


"""
    subscript(i::Int)
Transform `i` to a string that has `i` as a subscript.
"""
function subscript(i::Int)
    if i < 0
        "₋"*subscript(-i)
    elseif i == 1
        "₁"
    elseif i == 2
        "₂"
    elseif i == 3
        "₃"
    elseif i == 4
        "₄"
    elseif i == 5
        "₅"
    elseif i == 6
        "₆"
    elseif i == 7
        "₇"
    elseif i == 8
        "₈"
    elseif i == 9
        "₉"
    elseif i == 0
        "₀"
    else
        join(subscript.(digits(i)))
    end
end

"""
    superscript(i::Int)
Transform `i` to a string that has `i` as a superscript.
"""
function superscript(i::Int)
    if i < 0
        "⁻"*superscript(-i)
    elseif i == 1
        "¹"
    elseif i == 2
        "²"
    elseif i == 3
        "³"
    elseif i == 4
        "⁴"
    elseif i == 5
        "⁵"
    elseif i == 6
        "⁶"
    elseif i == 7
        "⁷"
    elseif i == 8
        "⁸"
    elseif i == 9
        "⁹"
    elseif i == 0
        "⁰"
    else
        join(superscript.(digits(i)))
    end
end

"""
    randomcolor(args...) = RGBAf(0.9 .* (rand(), rand(), rand())..., 0.75)
"""
randomcolor(args...) = RGBAf(0.9 .* (rand(), rand(), rand())..., 0.75)

function colors_from_map(cmap, N, α = 1)
    N == 1 && return [Makie.categorical_colors(cmap, 2)[1]]
    return [RGBAf(c.r, c.g, c.b, α) for c in Makie.categorical_colors(cmap, N)]
end

function pushupdate!(o::Observable, v)
    push!(o[], v)
    o[] = o[]
    return o
end

"""
    to_alpha(c, α = 0.75)
Create a color same as `c` but with given alpha channel.
"""
function to_alpha(c, α = 1.2)
    c = to_color(c)
    return RGBAf(c.r, c.g, c.b, α)
end

struct CyclicContainer{C} <: AbstractVector{C}
    c::Vector{C}
    n::Int
end
CyclicContainer(c) = CyclicContainer(c, 0)
Base.length(c::CyclicContainer) = length(c.c)
Base.size(c::CyclicContainer) = size(c.c)
Base.getindex(c::CyclicContainer, i) = c.c[mod1(i, length(c.c))]
function Base.getindex(c::CyclicContainer)
    c.n += 1
    c[c.n]
end
Base.iterate(c::CyclicContainer, i = 1) = iterate(c.c, i)

CYCLIC_COLORS = CyclicContainer(JULIADYNAMICS_COLORS)

##########################################################################################
# Polygon stuff
##########################################################################################
using Makie.GeometryBasics # for using Polygons

translate(p::Polygon, point) = Polygon(decompose(Point2f, p.exterior) .+ point)

"""
    rotate2D(p::Polygon, θ)
Rotate given polygon counter-clockwise by `θ` (in radians).
"""
function rotate2D(p::Polygon, θ)
    sinφ, cosφ = sincos(θ)
    Polygon(map(
        p -> Point2f(cosφ*p[1] - sinφ*p[2], sinφ*p[1] + cosφ*p[2]),
        decompose(Point2f, p.exterior)
    ))
end

"""
    scale(p::Polygon, s)
Scale given polygon by `s`, assuming polygon's "center" is the origin.
"""
scale(p::Polygon, s) = Polygon(decompose(Point2f, p.exterior) .* Float32(s))
