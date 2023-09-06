using Test, Agents, Random

@testset "@agent macro" begin
    @test ContinuousAgent <: AbstractAgent
    @agent struct A3 
        fieldsof(GridAgent{2})
        weight::Float64
    end
    @test A3 <: AbstractAgent
    @test fieldnames(A3) == (:id, :pos, :weight)
    @test fieldtypes(A3) == (Int, NTuple{2, Int}, Float64)

    """
    This is a test docstring for agent A4
    """
    @agent struct A4 
        fieldsof(A3)
        z::Bool
    end
    @test A4 <: AbstractAgent
    @test fieldnames(A4) == (:id, :pos, :weight, :z)
    @test fieldtypes(A4) == (Int, NTuple{2, Int}, Float64, Bool)
    @test contains(string(@doc(A4)), "This is a test docstring for agent A4")

    # Also test subtyping
    abstract type AbstractHuman <: AbstractAgent end

    @agent struct Worker <: AbstractHuman
        fieldsof(GridAgent{2})
        age::Int
        moneyz::Float64
    end
    @test Worker <: AbstractHuman
    @test :age ∈ fieldnames(Worker)

    @agent struct Fisher <: AbstractHuman
        fieldsof(Worker)
        fish_per_day::Float64
    end
    @test Fisher <: AbstractHuman
    @test :fish_per_day ∈ fieldnames(Fisher)

    @agent struct Agent9 
        fieldsof(NoSpaceAgent)
        f1::Int = 40
        f2::Int
        f3::Float64 = 3.0
    end
    agent_kwdef = Agent9(id = 1, f2 = 10)
    values = (1, 40, 10, 3.0)
    @test all(getfield(agent_kwdef, n) == v for (n, v) in zip(fieldnames(Agent9), values))
    agent_kwdef = Agent9(1, 20, 10, 4.0)
    values = (1, 20, 10, 4.0)
    @test all(getfield(agent_kwdef, n) == v for (n, v) in zip(fieldnames(Agent9), values))

    @agent struct Agent10 
        fieldsof(NoSpaceAgent)
        f1::Int
        const f2::Int
        f3::Float64
    end
    agent_consts = Agent10(1, 2, 10, 5.0)
    values = (1, 2, 10, 5.0)
    @test all(getfield(agent_consts, n) == v for (n, v) in zip(fieldnames(Agent10), values))
    agent_consts.f1 = 5
    @test agent_consts.f1 == 5
    @test_throws ErrorException agent_consts.f2 = 5

    @agent struct Agent11 
        fieldsof(NoSpaceAgent)
        const f1::Int
        const f2
        f3::Float64
    end
    agent_consts = Agent11(1, 2, 10, 5.0)
    values = (1, 2, 10, 5.0)
    @test all(getfield(agent_consts, n) == v for (n, v) in zip(fieldnames(Agent11), values))
    agent_consts.f3 = 2.0
    @test agent_consts.f3 == 2.0
    @test_throws ErrorException agent_consts.f1 = 5
    @test_throws ErrorException agent_consts.f2 = 5

    @agent struct Agent12 
        fieldsof(Agent11)
        const f4
        f5::Float64
    end
    agent_consts = Agent12(1, 2, 10, 5.0, true, 3.0)
    values = (1, 2, 10, 5.0, true, 3.0)
    @test all(getfield(agent_consts, n) == v for (n, v) in zip(fieldnames(Agent11), values))
    agent_consts.f3 = 2.0
    @test agent_consts.f3 == 2.0
    agent_consts.f5 = 4.0
    @test agent_consts.f5 == 4.0
    @test_throws ErrorException agent_consts.f1 = 5
    @test_throws ErrorException agent_consts.f2 = 5
    @test_throws ErrorException agent_consts.f4 = false
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
        "Agent type is not mutable, and most library functions assume that it is.",
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
    # Cannot use NoSpaceAgent in a grid space context since it has no `pos` field
    @test_throws ArgumentError ABM(NoSpaceAgent, GridSpace((1, 1)))
    agent = NoSpaceAgent(1)
    @test_throws ArgumentError ABM(agent, GridSpace((1, 1)))
    # Cannot use Gridagent in a graph space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(GridAgent{2}, GraphSpace(Agents.Graph(1)))
    agent = GridAgent{2}(1, (1, 1))
    @test_throws ArgumentError ABM(agent, GraphSpace(Agents.Graph(1)))
    # Cannot use GraphAgent in a continuous space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(GraphAgent, ContinuousSpace((1, 1)))

    # Shouldn't use DiscreteVelocity in a continuous space context since `vel` has an invalid type
    mutable struct DiscreteVelocity <: AbstractAgent
        id::Int
        pos::SVector{2,Float64}
        vel::SVector{2,Int}
        diameter::Float64
    end
    @test_throws ArgumentError ABM(DiscreteVelocity, ContinuousSpace((1, 1)))
    agent = DiscreteVelocity(1, SVector(1, 1), SVector(2, 3), 2.4)
    @test_throws ArgumentError ABM(agent, ContinuousSpace((1, 1)))
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
        Agent type is not concrete. If your agent is parametrically typed, you're probably
        seeing this warning because you gave `Agent` instead of `Agent{Float64}`
        (for example) to this function. You can also create an instance of your agent
        and pass it to this function. If you want to use `Union` types for mixed agent
        models, you can silence this warning.
        If you are using `ContinuousAgent{D}` as agent type in version 6+, update
        to the new two-parameter version `ContinuousAgent{D,Float64}` to obtain
        the same behavior as previous Agents.jl versions.\n"""
    ) ABM(ParametricAgent, GridSpace((1, 1)))
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(ParametricAgent, GridSpace((1, 1)); warn = false)) <:
          AbstractAgent
    # ParametricAgent{Int} is the correct way to use such an agent
    @test Agents.agenttype(ABM(ParametricAgent{Int}, GridSpace((1, 1)))) <: AbstractAgent
    #Type inferance using an instance can help users here
    agent = ParametricAgent(1, (1, 1), 5, "Info")
    @test Agents.agenttype(ABM(agent, GridSpace((1, 1)))) <: AbstractAgent
    #Mixed agents
    @agent struct ValidAgent 
        fieldsof(NoSpaceAgent)
        dummy::Bool
    end

    @test Agents.agenttype(ABM(Union{NoSpaceAgent,ValidAgent}; warn = false)) <: AbstractAgent
    @test_logs (
        :warn,
        """
        Agent type is not concrete. If your agent is parametrically typed, you're probably
        seeing this warning because you gave `Agent` instead of `Agent{Float64}`
        (for example) to this function. You can also create an instance of your agent
        and pass it to this function. If you want to use `Union` types for mixed agent
        models, you can silence this warning.
        If you are using `ContinuousAgent{D}` as agent type in version 6+, update
        to the new two-parameter version `ContinuousAgent{D,Float64}` to obtain
        the same behavior as previous Agents.jl versions.\n"""
    ) ABM(Union{NoSpaceAgent,ValidAgent})
    @test_throws ArgumentError ABM(Union{NoSpaceAgent,BadAgent}; warn = false)

    # this should work for backward compatibility but throw warning (#855)
    @test_logs (
        :warn,
        """
        Agent type is not concrete. If your agent is parametrically typed, you're probably
        seeing this warning because you gave `Agent` instead of `Agent{Float64}`
        (for example) to this function. You can also create an instance of your agent
        and pass it to this function. If you want to use `Union` types for mixed agent
        models, you can silence this warning.
        If you are using `ContinuousAgent{D}` as agent type in version 6+, update
        to the new two-parameter version `ContinuousAgent{D,Float64}` to obtain
        the same behavior as previous Agents.jl versions.\n"""
    ) ABM(ContinuousAgent{2}, ContinuousSpace((1,1)))
    # throws if the old ContinuousAgent{2} form is used with a non-Float64 space
    @test_throws ArgumentError ABM(ContinuousAgent{2}, ContinuousSpace((1f0,1f0)); warn=false)
end


