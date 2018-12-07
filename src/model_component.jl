

# """
# Define your model to be a subtype of AbstractModel.

# e.g.

# mutable struct MyModel <: AbstractModel
#   grid
# end
# """
# abstract type AbstractModel end

mutable struct Model
  seed::Int64
  rng::Distribution
  grid
  individuals::Integers
  max_individuals::Integer
end


function selection()
  # TODO
end

function run_model(a::Array{Agent}, m::Model)

end