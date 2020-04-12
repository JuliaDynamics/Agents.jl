using DynamicGrids, DynamicGridsGtk, ColorSchemes, Colors

const DEAD = 1
const ALIVE = 2
const BURNING = 3

struct ForestFire{R,N,PC,PR} <: NeighborhoodRule{R}
    neighborhood::N
    prob_combustion::PC
    prob_regrowth::PR
end
ForestFire(; neighborhood=RadialNeighborhood{1}(), prob_combustion=0.0001, prob_regrowth=0.01) =
    ForestFire{DynamicGrids.radius(neighborhood),typeof.((neighborhood, prob_combustion, prob_regrowth))...
              }(neighborhood, prob_combustion, prob_regrowth)

@inline DynamicGrids.applyrule(rule::ForestFire, data, state::Integer, index, hood_buffer) =
    if state == ALIVE
        if BURNING in hood_buffer
            BURNING
        else
            rand() <= rule.prob_combustion ? BURNING : ALIVE
        end
    elseif state in BURNING
        DEAD
    else
        rand() <= rule.prob_regrowth ? ALIVE : DEAD
    end

init = fill(ALIVE, 400, 400)
ruleset = Ruleset(ForestFire(); init=init)

output = ArrayOutput(init, 50)
@time sim!(output, ruleset; tspan=(1, 50))
