mutable struct Haploid <: AbstractAgent
    id::Int
    trait::Float64
end

"""
``` julia
wright_fisher(; 
    numagents = 100,
    selection = true
)
```
Same as in [Wright-Fisher model of evolution](@ref).
"""
function wright_fisher(; numagents = 100, selection = true)
    model = ABM(Haploid)
    for i in 1:numagents
        add_agent!(model, rand())
    end
    !selection && return model, wright_fisher_model_step_neutral!, dummystep
    return model, wright_fisher_model_step_selection!, dummystep
end

wright_fisher_model_step_neutral!(model::ABM) = sample!(model, nagents(model))

wright_fisher_model_step_selection!(model::ABM) = sample!(model, nagents(model), :trait)
