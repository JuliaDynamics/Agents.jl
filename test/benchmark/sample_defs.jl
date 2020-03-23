
mutable struct Haploid <: AbstractAgent
    id::Int
    trait::Float64
end
function sampleModelInitialize(;n = 100)
  sampleModel = ABM(Haploid)
  for i in 1:n
      add_agent!(sampleModel, rand())
  end
  return sampleModel
end

mutable struct HaploidS <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    trait::Float64
end
function sampleModelInitializeS(;n = 100, dims=(2,3))
  sampleModel = ABM(HaploidS, GridSpace(dims))
  for i in 1:n
      add_agent!(sampleModel, rand())
  end
  return sampleModel
end
