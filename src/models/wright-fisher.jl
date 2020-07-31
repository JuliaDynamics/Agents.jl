mutable struct Haploid <: AbstractAgent
    id::Int
    trait::Float64
end

""" julia
wright-fisher(; 
    numagents = 100,
    selection = true
)
Same as in [Wright-Fisher model of evolution](@ref).
"""
function wright-fisher(; numagents = 100, selection = true)
    model = ABM(Haploid)
    for i in 1:numagents
        add_agent!(model, rand())
    end
    !selection && return model, dummystep, modelstep_neutral!
    return model, dummystep, modelstep_selection!
end

modelstep_neutral!(model::ABM) = sample!(model, nagents(model))

modelstep_selection!(model::ABM) = sample!(model, nagents(model), :trait)