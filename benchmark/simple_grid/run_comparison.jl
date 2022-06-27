using Random, BenchmarkTools, Agents
# shared constants
const min_to_be_happy = 3 # how many nearby agents you need of same group
const grid_occupation = 0.8 # percentage of space occupied by agents
const grid_size = (30, 30)
const moore = [
    (1,0),  (1,1),  (1,-1),
    (0,1),          (0,-1),
    (-1,0), (-1,1), (-1,-1),
]

include("dict_based.jl")
include("gridspace_based.jl")