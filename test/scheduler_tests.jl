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

# Mixed model
function init_mixed_model(; scheduler = fastest)
    model = ABM(Union{Agent0,Agent1,Agent2,Agent3}, scheduler = scheduler, warn = false)
    for id in 1:5
        a0 = Agent0(id)
        add_agent!(a0, model)
    end
    for id in 6:10
        a1 = Agent1(id, (0, 0))
        add_agent!(a1, model)
    end
    for id in 11:15
        a2 = Agent2(id, 5.0)
        add_agent!(a2, model)
    end
    for id in 16:20
        a3 = Agent3(id, (0, 0), 5.0)
        add_agent!(a3, model)
    end
    return model
end

@testset "Mixed Scheduler" begin
    model = init_mixed_model()
    @test sort!(collect(model.scheduler(model))) == 1:20

    model = init_mixed_model(scheduler = by_type(fastest))
    @test sort!(collect(model.scheduler(model))) == 1:20

    model = init_mixed_model(scheduler = by_id)
    @test model.scheduler(model) == 1:20

    model = init_mixed_model(scheduler = by_type(by_id))
    @test model.scheduler(model) == 1:20

    # Swapping union order
    model = ABM(Union{Agent0,Agent1}, scheduler = by_type(by_id), warn = false)
    for id in 1:5
        a1 = Agent1(id, (0, 0))
        add_agent!(a1, model)
    end
    for id in 6:10
        a0 = Agent0(id)
        add_agent!(a0, model)
    end

    @test model.scheduler(model) == vcat(6:10, 1:5)

    Random.seed!(12)
    model = init_mixed_model(scheduler = random_activation)
    @test model.scheduler(model)[1:3] == [17, 5, 11] # reproducibility test

    Random.seed!(12)
    model = init_mixed_model(scheduler = by_type(random_activation))
    @test model.scheduler(model)[1:3] == [1, 2, 5] # reproducibility test

    Random.seed!(12)
    model = init_mixed_model(scheduler = partial_activation(0.5))
    @test model.scheduler(model) == [18, 16, 11, 17, 8, 4, 3, 5, 13]

    Random.seed!(12)
    model = init_mixed_model(scheduler = by_type(partial_activation, 0.5))
    @test model.scheduler(model) == [2, 3, 5, 8, 6, 13, 14, 15, 18]
    @test count(a -> a == Agent2, typeof(model[id]) for id in model.scheduler(model)) == 4
end

