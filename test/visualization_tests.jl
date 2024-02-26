
using CairoMakie
using OSMMakie
using GraphMakie
using AgentsExampleZoo

## Schelling

groupcolor(a) = a.group == 1 ? :blue : :orange
groupmarker(a) = a.group == 1 ? :circle : :rect
function schelling_test()
    model = AgentsExampleZoo.schelling()
    fig, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
    return fig
end

## Daisyworld

using Statistics: mean

daisycolor(a::AgentsExampleZoo.Daisy) = a.breed
plotkwargs = (;
    ac = daisycolor,
    as = 20,
    am = '✿',
    scatterkwargs = (strokewidth = 1.0,),
    heatarray = :temperature,
    heatkwargs = (colorrange = (-20, 60), colormap = :thermal)
)
params = Dict(
    :surface_albedo => 0:0.01:1,
    :solar_change => -0.1:0.01:0.1,
)

function daisyworld_test()
    model = AgentsExampleZoo.daisyworld(; solar_luminosity = 1.0, solar_change = 0.0, 
        scenario = :change)
    fig, _ = abmplot(model; params, plotkwargs...)
    return fig
end

function daisyworld_abmexploration(params, plotkwargs)
    model = Models.daisyworld(; solar_luminosity = 1.0, solar_change = 0.0, 
        scenario = :change)
    black(a) = a.breed == :black
    white(a) = a.breed == :white
    adata = [(black, count), (white, count)]
    temperature(model) = mean(model.temperature)
    mdata = [temperature, :solar_luminosity]
    fig, _ = abmexploration(model;
        params, plotkwargs...,  adata, alabels = ["Black daisys", "White daisys"], 
        mdata, mlabels = ["T", "L"]
    )
    return fig
end

## SIR

using GraphMakie.Graphs
using CairoMakie.Colors.ColorTypes
using GraphMakie: Shell

function sir_test()
    model = AgentsExampleZoo.sir()
    city_size(agents_here) = 0.005 * length(agents_here)
    function city_color(agents_here)
        l_agents_here = length(agents_here)
        infected = count(a.status == :I for a in agents_here)
        recovered = count(a.status == :R for a in agents_here)
        return RGB(infected / l_agents_here, recovered / l_agents_here, 0)
    end
    edge_color(model) = fill((:grey, 0.25), ne(abmspace(model).graph))
    function edge_width(model)
        w = zeros(ne(abmspace(model).graph))
        for e in edges(abmspace(model).graph)
            w[e.src] = 0.004 * length(abmspace(model).stored_ids[e.src])
            w[e.dst] = 0.004 * length(abmspace(model).stored_ids[e.dst])
        end
        return w
    end
    graphplotkwargs = (
        layout = Shell(), # node positions
        arrow_show = false, # hide directions of graph edges
        edge_color = edge_color, # change edge colors and widths with own functions
        edge_width = edge_width,
        edge_plottype = :linesegments # needed for tapered edge widths
    )

    fig, _ = abmplot(model; as = city_size, ac = city_color, graphplotkwargs)
    return fig
end

## Zombies

function zombies_test()
    zombie_color(agent) = agent.infected ? :green : :black
    zombie_size(agent) = agent.infected ? 10 : 8
    model = AgentsExampleZoo.zombies()
    fig, _ = abmplot(model; ac = zombie_color, as = zombie_size)
    return fig
end

## custom space Schelling model

# type P stands for Periodic and is a boolean
struct CustomSpace{D,P} <: Agents.AbstractGridSpace{D,P}
    stored_ids::Array{Int,D}
    extent::NTuple{D,Int}
    metric::Symbol
    offsets_at_radius::Vector{Vector{NTuple{D,Int}}}
    offsets_within_radius::Vector{Vector{NTuple{D,Int}}}
    offsets_within_radius_no_0::Vector{Vector{NTuple{D,Int}}}
    field_that_should_be_a_property_instead::Bool
end
spacesize(space::CustomSpace) = space.extent

"""
    CustomSpace(d::NTuple{D, Int}; periodic = true, metric = :chebyshev)
This is a specialized version of [`GridSpace`](@ref) that allows only one
agent per position, and utilizes this knowledge to offer significant performance
gains versus [`GridSpace`](@ref).

This space **reserves agent ID = 0 for internal usage.** Agents should be initialized
with non-zero IDs, either positive or negative. This is not checked internally.

All arguments and keywords behave exactly as in [`GridSpace`](@ref).
"""
function CustomSpace(d::NTuple{D,Int};
        periodic::Union{Bool,NTuple{D,Bool}} = true,
        metric = :chebyshev,
        field_that_should_be_a_property_instead = false,
    ) where {D}
    s = zeros(Int, d)
    return CustomSpace{D,periodic}(s, d, metric,
        Vector{Vector{NTuple{D,Int}}}(),
        Vector{Vector{NTuple{D,Int}}}(),
        Vector{Vector{NTuple{D,Int}}}(),
        field_that_should_be_a_property_instead,
    )
end

# Implementation of space API
function Agents.add_agent_to_space!(a::AbstractAgent, model::ABM{<:CustomSpace})
    pos = a.pos
    !isempty(pos, model) && error("Cannot add agent $(a) to occupied position $(pos)")
    abmspace(model).stored_ids[pos...] = a.id
    return a
end

function Agents.remove_agent_from_space!(a::AbstractAgent, model::ABM{<:CustomSpace})
    abmspace(model).stored_ids[a.pos...] = 0
    return a
end

function Agents.empty_positions(model::ABM{<:CustomSpace})
    Iterators.filter(i -> abmspace(model).stored_ids[i...] == 0, positions(model))
end

"""
    id_in_position(pos, model::ABM{<:CustomSpace}) → id

Return the agent ID in the given position.
This will be `0` if there is no agent in this position.

This is similar to [`ids_in_position`](@ref), but specialized for `CustomSpace`.
"""
Agents.ids_in_position(pos, model::ABM{<:CustomSpace}) = Agents.ids_in_position(pos, abmspace(model))
Agents.ids_in_position(pos, space::CustomSpace) = space.stored_ids[pos...]
Base.isempty(pos::Agents.ValidPos, model::ABM{<:CustomSpace}) = Agents.ids_in_position(pos, model) == 0 

#######################################################################################
# Implementation of nearby_stuff
#######################################################################################

function Agents.nearby_ids(pos::NTuple{D, Int}, model::ABM{<:CustomSpace{D,true}}, r = 1,
        get_offset_indices = Agents.offsets_within_radius # internal, see last function
    ) where {D}
    nindices = get_offset_indices(model, r)
    stored_ids = abmspace(model).stored_ids
    space_size = spacesize(abmspace(model))
    position_iterator = (pos .+ β for β in nindices)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        ids_iterator = (stored_ids[p...] for p in position_iterator
                        if stored_ids[p...] != 0)
    else
        ids_iterator = (checkbounds(Bool, stored_ids, p...) ?
                        stored_ids[p...] : stored_ids[mod1.(p, space_size)...]
                        for p in position_iterator if stored_ids[mod1.(p, space_size)...] != 0)
    end
    return ids_iterator
end

function Agents.nearby_ids(pos::NTuple{D, Int}, model::ABM{<:CustomSpace{D,false}}, r = 1,
        get_offset_indices = Agents.offsets_within_radius # internal, see last function
    ) where {D}
    nindices = get_offset_indices(model, r)
    stored_ids = abmspace(model).stored_ids
    space_size = spacesize(abmspace(model))
    position_iterator = (pos .+ β for β in nindices)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        ids_iterator = (stored_ids[p...] for p in position_iterator
                        if stored_ids[p...] != 0)
    else
        ids_iterator = (stored_ids[p...] for p in position_iterator
                        if checkbounds(Bool, stored_ids, p...) && stored_ids[p...] != 0)
    end
    return ids_iterator
end

function Agents.nearby_ids(pos::NTuple{D, Int}, model::ABM{<:CustomSpace{D,P}}, r = 1,
        get_offset_indices = Agents.offsets_within_radius # internal, see last function
    ) where {D,P}
    nindices = get_offset_indices(model, r)
    stored_ids = abmspace(model).stored_ids
    space_size = size(stored_ids)
    position_iterator = (pos .+ β for β in nindices)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        ids_iterator = (stored_ids[p...] for p in position_iterator
                        if stored_ids[p...] != 0)
    else
        ids_iterator = (
            checkbounds(Bool, stored_ids, p...) ?
            stored_ids[p...] : stored_ids[mod1.(p, space_size)...]
            for p in position_iterator
            if stored_ids[mod1.(p, space_size)...] != 0 &&
            all(P[i] || checkbounds(Bool, axes(stored_ids, i), p[i]) for i in 1:D)
        )
    end
    return ids_iterator
end

function Agents.nearby_ids(
    a::AbstractAgent, model::ABM{<:CustomSpace}, r = 1)
    return nearby_ids(a.pos, model, r, Agents.offsets_within_radius_no_0)
end

## Visualisation API

#######################################################################################
# %% REQUIRED
#######################################################################################

const ABMPlot = Agents.get_ABMPlot_type()

Agents.agents_space_dimensionality(::CustomSpace{D}) where {D} = D

function Agents.get_axis_limits(model::ABM{<:CustomSpace})
    e = size(abmspace(model)) .+ 0.5
    o = zero.(e) .+ 0.5
    return o, e
end

function Agents.agentsplot!(ax::Axis, p::ABMPlot)
    scatter!(p, p.pos; color = :red, p.marker, p.markersize, p.scatterkwargs...)
    return p
end

function Agents.ids_to_inspect(model::ABM{<:CustomSpace}, pos)
    id = id_in_position(pos, model)
    return id == 0 ? () : (id,)
end

function custom_space_schelling_test()
    space = CustomSpace((20, 20); 
        periodic = false,
        field_that_should_be_a_property_instead = true
    )
    properties = Dict(:min_to_be_happy => 3)
    model = StandardABM(AgentsExampleZoo.SchellingAgent, space;
        properties, agent_step! = AgentsExampleZoo.schelling_agent_step!,
        container = Vector, scheduler = Schedulers.Randomly()
    )
    for n in 1:320
        add_agent_single!(AgentsExampleZoo.SchellingAgent, model, false, n < 320 / 2 ? 1 : 2)
    end
    fig, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
    return fig
end

## Nothing space

@agent struct NothingAgent(NoSpaceAgent)
    age::Int
end

function nothing_step!(a, m)
    a.age += 1
    rand(abmrng(m)) < (m.d * a.age) && remove_agent!(a, m)
    if nagents(m) >= 2
        if 14 <= a.age <= 70
            rand(abmrng(m)) < (m.b * a.age) && add_agent!(m, 0)
        end
    end
end

function nothing_model()
    properties = Dict(:b => 0.003, :d => 0.002)
    model = ABM(NothingAgent; agent_step! = nothing_step!, properties)
    for _ in 1:1000
        add_agent!(model, rand(abmrng(model), 0:100))
    end
    return model
end

function nothing_test()
    model = nothing_model()
    params = Dict(:b => 0:0.0001:0.005, :d => 0:0.0005:0.01)
    adata = [(:age, maximum), (:age, mean), (:age, minimum)]
    mdata = [nagents]
    fig, _ = abmexploration(model; adata, mdata, params)
    return fig
end

# TODO: write actual tests
@testset "agent visualizations" begin
    nothing_test()
    schelling_test()
    daisyworld_test()
    sir_test()
    zombies_test()
    custom_space_schelling_test()
end
