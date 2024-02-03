"""
    agent_validator(AgentType, space)
Validate the user supplied agent (subtype of `AbstractAgent`).
Checks for mutability and existence and correct types for fields depending on `SpaceType`.
"""
function agent_validator(
    ::Type{A},
    space::S,
    warn::Bool,
) where {A<:AbstractAgent,S<:SpaceType}
    # Check A for required properties & fields
    if isconcretetype(A)
        do_checks(A, space, warn)
    else
        warn && @warn """
        Agent type is not concrete. If your agent is parametrically typed, you're probably
        seeing this warning because you gave `Agent` instead of `Agent{Float64}`
        (for example) to this function. You can also create an instance of your agent
        and pass it to this function. If you want to use `Union` types for mixed agent
        models, you can silence this warning.
        If you are using `ContinuousAgent{D}` as agent type in version 6+, update
        to the new two-parameter version `ContinuousAgent{D,Float64}` to obtain
        the same behavior as previous Agents.jl versions.
        """
        for type in union_types(A)
            do_checks(type, space, warn)
        end
    end
end

# Note: This function needs to be updated every time a new space is defined!
"""
    do_checks(agent, space)
Helper function for `agent_validator`.
"""
function do_checks(::Type{A}, space::S, warn::Bool) where {A<:AbstractAgent, S<:SpaceType}
    if warn
        isbitstype(A) &&
        @warn "Agent type is not mutable, and most library functions assume that it is."
    end
    (any(isequal(:id), fieldnames(A)) && fieldnames(A)[1] == :id) ||
    throw(ArgumentError("First field of agent type must be `id` (and should be of type `Int`)."))
    fieldtype(A, :id) <: Integer ||
    throw(ArgumentError("`id` field in agent type must be of type `Int`."))
    if space !== nothing
        (any(isequal(:pos), fieldnames(A)) && fieldnames(A)[2] == :pos) ||
        throw(ArgumentError("Second field of agent type must be `pos` when using a space."))
        # Check `pos` field in A has the correct type
        pos_type = fieldtype(A, :pos)
        space_type = typeof(space)
        if space_type <: GraphSpace && !(pos_type <: Integer)
            throw(ArgumentError("`pos` field in agent type must be of type `Int` when using GraphSpace."))
        elseif space_type <: GridSpace && !(pos_type <: NTuple{D,Integer} where {D})
            throw(ArgumentError("`pos` field in agent type must be of type `NTuple{Int}` when using GridSpace."))
        elseif space_type <: ContinuousSpace
            if pos_type <: NTuple{D,<:AbstractFloat} where {D}
                warn && @warn "Using `NTuple` for the `pos` and `vel` fields of agent types in ContinuousSpace is deprecated. Use `SVector` instead."
            elseif !(pos_type <: SVector{D,<:AbstractFloat} where {D} || (!isconcretetype(A) && pos_type <: SVector{D} where {D}))
                throw(ArgumentError("`pos` field in agent type must be of type `SVector{<:AbstractFloat}` when using ContinuousSpace."))
            end
            if any(isequal(:vel), fieldnames(A)) &&
               !(
                    fieldtype(A, :vel) <: NTuple{D,<:AbstractFloat} where {D} ||
                    fieldtype(A, :vel) <: SVector{D,<:AbstractFloat} where {D} ||
                    (!isconcretetype(A) && fieldtype(A, :vel) <: SVector{D} where {D})
                )
                throw(ArgumentError("`vel` field in agent type must be of type `SVector{<:AbstractFloat}` when using ContinuousSpace."))
            end
            if eltype(space) != eltype(pos_type)
                # extra condition for backward compatibility (#855)
                # we don't want to throw an error if ContinuousAgent{D} is used with a Float64 space
                if isnothing(match(r"ContinuousAgent{\d}", string(A))) || eltype(space) != Float64
                    throw(ArgumentError("`pos` field in agent type must be of the same type of the `extent` field in ContinuousSpace."))
                end
            end
        end
    end
end
