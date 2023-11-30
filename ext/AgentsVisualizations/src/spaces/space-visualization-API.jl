#=
This file establishes the custom space visualization API.
All space types should implement this API (and be subtypes of `AbstractSpace`).

1. Required
    Remember to also copy the first line defining the ABMPlot type in your working 
    environment which is necesary to be able to extend the API.
    Inside ABMPlot you can find all the plot args and kwargs as well as the plot properties 
    that have been lifted from them (see section 3 of this API).
    You can then easily accessible them inside your functions via the dot syntax, e.g. with
    `p.color` or `p.plotkwargs`.
2. Preplots (optional)
3. Lifting (optional)
4. Inspection (optional)

Some functions DO NOT need to be implemented for every space, they are optional.
The necessity to implement these methods depends on the supertypes of your custom type.
For instance, you get a lot of methods "for free" if your CustomType is a subtype of 
Agents.AbstractGridSpace.
As a general rule of thumb: The more abstract your CustomSpace's supertype is, the more 
methods you will have to extend.

To implement this API for your custom space, copy the content of this file, replace 
Agents.AbstractSpace with CustomSpace (where CustomSpace is the name of your space type), implement at least the required methods, and finally remove the unused sections.

The same approach applies in the case that you should want to overwrite the default methods 
for an already existing space type.

In short: At least implement all functions in section "Required" with the same arguments!
=#

## Required
const ABMPlot = Agents.get_ABMPlot_type()

function Agents.agents_space_dimensionality(space::Agents.AbstractSpace) 
end

function Agents.get_axis_limits(model::ABM{<:Agents.AbstractSpace})
end

function Agents.agentsplot!(ax, model::ABM{<:Agents.AbstractSpace}, p::ABMPlot)
end

## Preplots

function Agents.spaceplot!(ax, model::ABM{<:Agents.AbstractSpace}; spaceplotkwargs...)
end

function Agents.static_preplot!(ax, model::ABM{<:Agents.AbstractSpace}, p::ABMPlot)
end

## Lifting

function Agents.abmplot_heatobs(model::ABM{<:Agents.AbstractSpace}, heatarray)
end

function Agents.abmplot_ids(model::ABM{<:Agents.AbstractSpace})
end

function Agents.abmplot_pos(model::ABM{<:Agents.AbstractSpace}, offset, ids)
end

function Agents.abmplot_colors(model::ABM{<:Agents.AbstractSpace}, ac, ids)
end
function Agents.abmplot_colors(model::ABM{<:Agents.AbstractSpace}, ac::Function, ids)
end

function Agents.abmplot_markers(model::ABM{<:Agents.AbstractSpace}, used_poly, am, pos, ids)
end
function Agents.abmplot_markers(model::ABM{<:Agents.AbstractSpace}, used_poly, am::Function, pos, ids)
end

function Agents.abmplot_markersizes(model::ABM{<:Agents.AbstractSpace}, as, ids)
end
function Agents.abmplot_markersizes(model::ABM{<:Agents.AbstractSpace}, as::Function, ids)
end

## Inspection

function Agents.convert_mouse_position(::S, pos) where {S<:Agents.AbstractSpace}
end

function Agents.ids_to_inspect(model::ABM{<:Agents.AbstractSpace}, pos)
end
