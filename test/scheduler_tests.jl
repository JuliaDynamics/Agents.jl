# %% Scheduler tests
@testset "Standard Scheduler" begin
    N = 1000

    # by_id
    model = ABM(Agent0; scheduler = by_id)
    for i in 1:N
        add_agent!(model)
    end
    @test sort!(collect(keys(model.agents))) == 1:N
    @test model.scheduler(model) == 1:N

    # fastest
    Random.seed!(12)
    model = ABM(Agent0; scheduler = fastest)
    for i in 1:N
        add_agent!(model)
    end
    @test sort!(collect(model.scheduler(model))) == 1:N

    # random
    Random.seed!(12)
    model = ABM(Agent0; scheduler = random_activation)
    for i in 1:N
        add_agent!(model)
    end
    @test model.scheduler(model)[1:3] == [913, 522, 637] # reproducibility test

    # partial
    Random.seed!(12)
    model = ABM(Agent0; scheduler = partial_activation(0.1))
    for i in 1:N
        add_agent!(model)
    end

    a = model.scheduler(model)
    @test length(a) < N
    @test a[1] == 74 # reproducibility test

    # by property
    model = ABM(Agent2; scheduler = property_activation(:weight))
    for i in 1:N
        add_agent!(model, rand() / rand())
    end

    Random.seed!(12)
    a = model.scheduler(model)

    ids = collect(keys(model.agents))
    properties = [model.agents[id].weight for id in ids]

    @test ids[sortperm(properties)] == a
end

@testset "Union Types" begin
    @test Agents.union_types(Union{Agent0}) == (Agent0,)
    @test Agents.union_types(Union{Agent0,Agent1}) == (Agent0, Agent1)
    @test Agents.union_types(Union{Agent0,Agent1,Agent2,Agent3}) ==
          (Agent0, Agent1, Agent2, Agent3)
    #Union types are not order preserving
    @test Agents.union_types(Union{Agent1,Agent0}) == (Agent0, Agent1)
    @test Agents.union_types(Union{Agent1,Agent3,Agent2,Agent0}) ==
          (Agent0, Agent1, Agent2, Agent3)
end

# Mixed model
function init_mixed_model(; scheduler = fastest)
    model = ABM(Union{Agent0,Agent1,Agent2,Agent3}, scheduler = scheduler, warn = false)
    for id in 1:20
        choice = rand(0:3)
        if choice == 0
            a0 = Agent0(id)
            add_agent!(a0, model)
        elseif choice == 1
            a1 = Agent1(id, (0, 0))
            add_agent!(a1, model)
        elseif choice == 2
            a2 = Agent2(id, 5.0)
            add_agent!(a2, model)
        elseif choice == 3
            a3 = Agent3(id, (0, 0), 5.0)
            add_agent!(a3, model)
        end
    end
    return model
end

@testset "Mixed Scheduler" begin
    # Type shuffles
    model = init_mixed_model()
    @test sort!(collect(model.scheduler(model))) == 1:20

    Random.seed!(12)
    model = init_mixed_model(scheduler = by_type(false, false))
    @test [typeof(model[id]) for id in model.scheduler(model)] == [
        Agent0,
        Agent0,
        Agent0,
        Agent0,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent3,
        Agent3,
        Agent3,
    ]
    @test model.scheduler(model)[1:3] == [18, 7, 10]
    @test count(a -> a == Agent2, typeof(model[id]) for id in model.scheduler(model)) == 6

    Random.seed!(13)
    model = init_mixed_model(scheduler = by_type(true, false))
    @test [typeof(model[id]) for id in model.scheduler(model)] == [
        Agent3,
        Agent3,
        Agent3,
        Agent3,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent0,
        Agent0,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
    ]
    @test model.scheduler(model)[1:3] == [2, 16, 10]
    @test count(a -> a == Agent2, typeof(model[id]) for id in model.scheduler(model)) == 7

    # Offset union order and ids
    Random.seed!(833)
    model = ABM(Union{Agent0,Agent1}, scheduler = by_type(false, false), warn = false)
    for id in 1:3
        a1 = Agent1(id, (0, 0))
        add_agent!(a1, model)
    end
    for id in 4:6
        a0 = Agent0(id)
        add_agent!(a0, model)
    end
    @test [typeof(model[id]) for id in model.scheduler(model)] ==
          [Agent0, Agent0, Agent0, Agent1, Agent1, Agent1]

    Random.seed!(833)
    model = ABM(
        Union{Agent1,Agent0},
        scheduler = by_type((Agent1, Agent0), false),
        warn = false,
    )
    for id in 1:3
        a1 = Agent1(id, (0, 0))
        add_agent!(a1, model)
    end
    for id in 4:6
        a0 = Agent0(id)
        add_agent!(a0, model)
    end
    @test [typeof(model[id]) for id in model.scheduler(model)] ==
          [Agent1, Agent1, Agent1, Agent0, Agent0, Agent0]
    @test model.scheduler(model) == [2, 3, 1, 4, 5, 6]

    # Agent shuffles
    Random.seed!(12)
    # Same seed as before, should be shuffled.
    model = init_mixed_model(scheduler = by_type(false, true))
    @test [typeof(model[id]) for id in model.scheduler(model)] == [
        Agent0,
        Agent0,
        Agent0,
        Agent0,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent3,
        Agent3,
        Agent3,
    ]
    @test model.scheduler(model)[1:3] != [18, 7, 10]
    # Shoul still be grouped correctly.

    Random.seed!(13)
    # Shuffle both type and agents
    model = init_mixed_model(scheduler = by_type(true, true))
    # Type order expected to be out of order, but the same as above due to seed
    @test [typeof(model[id]) for id in model.scheduler(model)] == [
        Agent3,
        Agent3,
        Agent3,
        Agent3,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent1,
        Agent0,
        Agent0,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
        Agent2,
    ]
    # Agent order expected to be different
    @test model.scheduler(model)[1:3] != [7, 9, 14]

    Random.seed!(833)
    model =
        ABM(Union{Agent1,Agent0}, scheduler = by_type((Agent1, Agent0), true), warn = false)
    for id in 1:3
        a1 = Agent1(id, (0, 0))
        add_agent!(a1, model)
    end
    for id in 4:6
        a0 = Agent0(id)
        add_agent!(a0, model)
    end
    @test [typeof(model[id]) for id in model.scheduler(model)] ==
          [Agent1, Agent1, Agent1, Agent0, Agent0, Agent0]
    @test model.scheduler(model) == [3, 2, 1, 4, 6, 5]
end


