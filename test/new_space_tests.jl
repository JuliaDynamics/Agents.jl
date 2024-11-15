using Test, Agents

@testset "create new space" begin
    struct DummySpace <: Agents.AbstractSpace
        ids::Set{Int}
    end

    DummySpace() = DummySpace(Set{Int}())

    Agents.random_position(::ABM{<:DummySpace}) = nothing

    function Agents.add_agent_to_space!(agent::Agents.AbstractAgent, model::ABM{<:DummySpace})
        space = Agents.abmspace(model)
        push!(space.ids, agent.id)
        return agent
    end

    function Agents.remove_agent_from_space!(agent::Agents.AbstractAgent, model::ABM{<:DummySpace})
        space = Agents.abmspace(model)
        delete!(space.ids, agent.id)
        return agent
    end


    @agent struct DummyAgent(NoSpaceAgent)
        pos::Nothing
    end

    model = StandardABM(DummyAgent, DummySpace(); agent_step! = (a, m) -> a)

    for i in 1:3
        add_agent!(DummyAgent, model)
        @test nagents(model) == i
    end

    remove_all!(model)
    @test iszero(nagents(model))
end
