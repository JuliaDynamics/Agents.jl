using Agents

@agent struct GraphAgentOne
    fieldsof(GraphAgent)
    one::Float64
    two::Bool
end

@agent struct GraphAgentTwo
    fieldsof(GraphAgent)
end

@agent struct GraphAgentThree
    fieldsof(GraphAgent)
end

@agent struct GraphAgentFour
    fieldsof(GraphAgent)
end

@agent struct GraphAgentFive
    fieldsof(GraphAgent)
end

@agent struct GridAgentOne
    fieldsof(GridAgent{2})
    one::Float64
    two::Bool
end

@agent struct GridAgentTwo <: AbstractAgent
    fieldsof(GridAgent{2})
end

@agent struct GridAgentThree <: AbstractAgent
    fieldsof(GridAgent{2})
end

@agent struct GridAgentFour <: AbstractAgent
    fieldsof(GridAgent{2})
end

@agent struct GridAgentFive <: AbstractAgent
    fieldsof(GridAgent{2})
end

@agent struct ContinuousAgentOne <: AbstractAgent
    fieldsof(ContinuousAgent{3,Float64})
    one::Float64
    two::Bool
end

@agent struct ContinuousAgentTwo
    fieldsof(ContinuousAgent{3,Float64})
end

@agent struct ContinuousAgentThree
    fieldsof(ContinuousAgent{3,Float64})
end

@agent struct ContinuousAgentFour
    fieldsof(ContinuousAgent{3,Float64})
end

@agent struct ContinuousAgentFive
    fieldsof(ContinuousAgent{3,Float64})
end

