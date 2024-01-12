using Agents

@agent struct GraphAgentOne(GraphAgent)
    one::Float64
    two::Bool
end

@agent struct GraphAgentTwo(GraphAgent)
end

@agent struct GraphAgentThree(GraphAgent)
end

@agent struct GraphAgentFour(GraphAgent)
end

@agent struct GraphAgentFive(GraphAgent)
end

@agent struct GridAgentOne(GridAgent{2})
    one::Float64
    two::Bool
end

@agent struct GridAgentTwo(GridAgent{2}) <: AbstractAgent
end

@agent struct GridAgentThree(GridAgent{2}) <: AbstractAgent
end

@agent struct GridAgentFour(GridAgent{2}) <: AbstractAgent
end

@agent struct GridAgentFive(GridAgent{2}) <: AbstractAgent
end

@agent struct ContinuousAgentOne(ContinuousAgent{3,Float64}) <: AbstractAgent
    one::Float64
    two::Bool
end

@agent struct ContinuousAgentTwo(ContinuousAgent{3,Float64})
end

@agent struct ContinuousAgentThree(ContinuousAgent{3,Float64})
end

@agent struct ContinuousAgentFour(ContinuousAgent{3,Float64})
end

@agent struct ContinuousAgentFive(ContinuousAgent{3,Float64})
end

