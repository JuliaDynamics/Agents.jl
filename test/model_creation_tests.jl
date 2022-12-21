using Test, Agents, Random

@testset "@agent macro" begin
    @test ContinuousAgent <: AbstractAgent
    @agent A3 GridAgent{2} begin
        weight::Float64
    end
    @test A3 <: AbstractAgent
    @test fieldnames(A3) == (:id, :pos, :weight)
    @test fieldtypes(A3) == (Int, NTuple{2, Int}, Float64)

    """
    This is a test docstring for agent A4
    """
    @agent A4 A3 begin
        z::Bool
    end
    @test A4 <: AbstractAgent
    @test fieldnames(A4) == (:id, :pos, :weight, :z)
    @test fieldtypes(A4) == (Int, NTuple{2, Int}, Float64, Bool)
    @test contains(string(@doc(A4)), "This is a test docstring for agent A4")

    # Also test subtyping
    abstract type AbstractHuman <: AbstractAgent end

    @agent Worker GridAgent{2} AbstractHuman begin
        age::Int
        moneyz::Float64
    end
    @test Worker <: AbstractHuman
    @test :age ∈ fieldnames(Worker)

    @agent Fisher Worker AbstractHuman begin
        fish_per_day::Float64
    end
    @test Fisher <: AbstractHuman
    @test :fish_per_day ∈ fieldnames(Fisher)
end


@testset "Model construction" begin
    mutable struct BadAgent <: AbstractAgent
        useless::Int
        pos::Int
    end
    mutable struct BadAgentId <: AbstractAgent
        id::Float64
    end
    struct ImmutableAgent <: AbstractAgent
        id::Int
    end

    # Shouldn't use ImmutableAgent since it cannot be edited
    agent = ImmutableAgent(1)
    @test_logs (
        :warn,
        "AgentType is not mutable. You probably haven't used `@agent`!",
    ) ABM(agent)
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(agent; warn = false)) <: AbstractAgent
    # Cannot use BadAgent since it has no `id` field
    @test_throws ArgumentError ABM(BadAgent)
    agent = BadAgent(1, 1)
    @test_throws ArgumentError ABM(agent)
    # Cannot use BadAgent in a grid space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(BadAgent, GridSpace((1, 1)))
    @test_throws ArgumentError ABM(agent, GridSpace((1, 1)))
    # Cannot use BadAgentId since `id` has an invalid type
    @test_throws ArgumentError ABM(BadAgentId)
    agent = BadAgentId(1.0)
    @test_throws ArgumentError ABM(agent)
    # Warn the user about using NoSpaceAgent in a grid space context since it has no `pos` field
    @test_logs (
        :warn,
        "Second field of Agent struct must be `pos` when using a space, unless you are purposely working with a NoSpaceAgent."
    ) match_mode=:any ABM(NoSpaceAgent, GridSpace((1, 1)))
    agent = NoSpaceAgent(1)
    @test_logs (
        :warn,
        "Second field of Agent struct must be `pos` when using a space, unless you are purposely working with a NoSpaceAgent."
    ) match_mode=:any ABM(agent, GridSpace((1, 1)))
    @test_logs ABM(NoSpaceAgent, GridSpace((1, 1)), warn=false) #no warnings with warn=false
    # Cannot use Gridagent in a graph space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(GridAgent{2}, GraphSpace(Agents.Graph(1)))
    agent = GridAgent{2}(1, (1, 1))
    @test_throws ArgumentError ABM(agent, GraphSpace(Agents.Graph(1)))
    # Cannot use GraphAgent in a continuous space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(GraphAgent, ContinuousSpace((1, 1)))

    # Shouldn't use DiscreteVelocity in a continuous space context since `vel` has an invalid type
    mutable struct DiscreteVelocity <: AbstractAgent
        id::Int
        pos::NTuple{2,Float64}
        vel::NTuple{2,Int}
        diameter::Float64
    end
    @test_logs (
        :warn,
        "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace.",
    ) match_mode=:any ABM(DiscreteVelocity, ContinuousSpace((1, 1)))
    agent = DiscreteVelocity(1, (1, 1), (2, 3), 2.4)
    @test_logs (
        :warn,
        "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace.",
    ) match_mode=:any ABM(agent, ContinuousSpace((1, 1)))
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(agent, ContinuousSpace((1, 1)); warn = false)) <: AbstractAgent
    # Shouldn't use ParametricAgent since it is not a concrete type
    mutable struct ParametricAgent{T<:Integer} <: AbstractAgent
        id::T
        pos::NTuple{2,T}
        weight::T
        info::String
    end
    @test_logs (
        :warn,
        """
        AgentType is not concrete. If your agent is parametrically typed, you're probably
        seeing this warning because you gave `Agent` instead of `Agent{Float64}`
        (for example) to this function. You can also create an instance of your agent
        and pass it to this function. If you want to use `Union` types for mixed agent
        models, you can silence this warning by passing `warn=false` to `AgentBasedModel()`.\n"""
    ) match_mode=:any ABM(ParametricAgent, GridSpace((1, 1)))
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(ParametricAgent, GridSpace((1, 1)); warn = false)) <:
          AbstractAgent
    # ParametricAgent{Int} is the correct way to use such an agent
    @test Agents.agenttype(ABM(ParametricAgent{Int}, GridSpace((1, 1)))) <: AbstractAgent
    #Type inference using an instance can help users here
    agent = ParametricAgent(1, (1, 1), 5, "Info")
    @test Agents.agenttype(ABM(agent, GridSpace((1, 1)))) <: AbstractAgent
    #Mixed agents
    @agent ValidAgent NoSpaceAgent begin
        dummy::Bool
    end

    @test Agents.agenttype(ABM(Union{NoSpaceAgent,ValidAgent}; warn = false)) <: AbstractAgent
    @test_logs (
        :warn,
        """
        AgentType is not concrete. If your agent is parametrically typed, you're probably
        seeing this warning because you gave `Agent` instead of `Agent{Float64}`
        (for example) to this function. You can also create an instance of your agent
        and pass it to this function. If you want to use `Union` types for mixed agent
        models, you can silence this warning by passing `warn=false` to `AgentBasedModel()`.\n"""
    ) ABM(Union{NoSpaceAgent,ValidAgent})
    @test_throws ArgumentError ABM(Union{NoSpaceAgent,BadAgent}; warn = false)
end
