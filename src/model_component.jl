

"""
Define your model to be a subtype of AbstractModel. Your model has to have the following fields, but can also have other fields of your choice.

e.g.

mutable struct MyModel <: AbstractModel
  seed
  rng
  grid
  individuals
end
"""
abstract type AbstractModel
  seed::Int64
  rng::Distribution
  grid
  individuals::Array{Integer}  # a list of individual ids
end

"""
An optional function to change model-level parameters at each step.
"""
function selection()
  # TODO
end

# function run_model(a::Array{AbstractAgent}, m::AbstractModel)
# end