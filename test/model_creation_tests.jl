@testset "Model construction" begin
    # Shouldn't use ImmutableAgent since it cannot be edited
    agent = ImmutableAgent(1)
    @test_logs (
        :warn,
        "AgentType should be mutable. Try adding the `mutable` keyword infront of `struct` in your agent definition.",
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
    # Cannot use Agent0 in a grid space context since it has no `pos` field
    @test_throws ArgumentError ABM(Agent0, GridSpace((1, 1)))
    agent = Agent0(1)
    @test_throws ArgumentError ABM(agent, GridSpace((1, 1)))
    # Cannot use Agent3 in a graph space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(Agent3, GraphSpace(Agents.Graph(1)))
    agent = Agent3(1, (1, 1), 5.3)
    @test_throws ArgumentError ABM(agent, GraphSpace(Agents.Graph(1)))
    # Cannot use Agent3 in a continuous space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(Agent3, ContinuousSpace((1, 1), 0.1))
    @test_throws ArgumentError ABM(agent, ContinuousSpace((1, 1), 0.1))
    # Cannot use Agent4 in a continuous space context since it has no `vel` field
    @test_throws ArgumentError ABM(Agent4, ContinuousSpace((1, 1), 0.1))
    agent = Agent4(1, (1, 1), 5)
    @test_throws ArgumentError ABM(agent, ContinuousSpace((1, 1), 0.1))
    # Shouldn't use DiscreteVelocity in a continuous space context since `vel` has an invalid type
    @test_logs (
        :warn,
        "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace.",
    ) ABM(DiscreteVelocity, ContinuousSpace((1, 1), 0.1))
    agent = DiscreteVelocity(1, (1, 1), (2, 3), 2.4)
    @test_logs (
        :warn,
        "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace.",
    ) ABM(agent, ContinuousSpace((1, 1), 0.1))
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(agent, ContinuousSpace((1, 1), 0.1); warn = false)) <:
          AbstractAgent
    # Shouldn't use ParametricAgent since it is not a concrete type
    @test_logs (
        :warn,
        "AgentType is not concrete. If your agent is parametrically typed, you're probably seeing this warning because you gave `Agent` instead of `Agent{Float64}` (for example) to this function. You can also create an instance of your agent and pass it to this function. If you want to use `Union` types for mixed agent models, you can silence this warning.",
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
    @test Agents.agenttype(ABM(Union{Agent0,Agent1}; warn = false)) <: AbstractAgent
    @test_logs (
        :warn,
        "AgentType is not concrete. If your agent is parametrically typed, you're probably seeing this warning because you gave `Agent` instead of `Agent{Float64}` (for example) to this function. You can also create an instance of your agent and pass it to this function. If you want to use `Union` types for mixed agent models, you can silence this warning.",
    ) ABM(Union{Agent0,Agent1})
    @test_throws ArgumentError ABM(Union{Agent0,BadAgent}; warn = false)
    @test_throws ArgumentError ABM(Agent6, GridSpace((50, 50)))
    @test_throws ErrorException Agents.notimplemented(ABM(Agent0))
    # Test @agent macro
    @agent A3 GridAgent{2} begin
        weight::Float64
    end
    @test A3 <: AbstractAgent
    @test fieldnames(A3) == fieldnames(Agent3)
    @test A3.types == Agent3.types
end