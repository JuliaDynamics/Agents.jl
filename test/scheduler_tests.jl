# %% Scheduler tests
@testset "Scheduler tests" begin

@testset "Simple schedulers" begin
    N = 1000

    # fastest
    Random.seed!(12)
    model = StandardABM(Agent0; scheduler = Schedulers.fastest, warn_deprecation = false)
    for i in 1:N
        add_agent!(model)
    end
    @test sort!(collect(abmscheduler(model)(model))) == 1:N

    # Schedulers.ByID
    model = StandardABM(Agent0; scheduler = Schedulers.ByID(), warn_deprecation = false)
    for i in 1:N
        add_agent!(model)
    end
    @test sort!(collect(allids(model))) == 1:N
    @test abmscheduler(model)(model) == 1:N

    # random
    model = StandardABM(Agent0; scheduler = Schedulers.Randomly(), rng = StableRNG(12), warn_deprecation = false)
    for i in 1:N
        add_agent!(model)
    end
    fastest_order = collect(allids(model))[1:3]
    @test abmscheduler(model)(model)[1:3] != fastest_order

    # partial
    model = StandardABM(Agent0; scheduler = Schedulers.Partially(0.1), rng = StableRNG(12), warn_deprecation = false)
    for i in 1:N
        add_agent!(model)
    end

    a = abmscheduler(model)(model)
    @test length(a) <= N/10

    # by property
    model = StandardABM(Agent2; scheduler = Schedulers.ByProperty(:weight), warn_deprecation = false)
    for i in 1:N
        add_agent!(model, rand(abmrng(model)) / rand(abmrng(model)))
    end

    Random.seed!(12)
    a = collect(abmscheduler(model)(model))

    ids = collect(allids(model))
    properties = [model[id].weight for id in ids]

    @test ids[sortperm(properties)] == a

    # Mixed model
    function init_mixed_model2(choices = [3, 3, 3, 3]; scheduler = Schedulers.fastest)
        model = StandardABM(Union{Agent0,Agent1,Agent2,Agent3}, scheduler = scheduler, warn = false, warn_deprecation = false)
        atypes = (Agent0,Agent1,Agent2,Agent3)
        id = 1
        for i in 1:choices[1]
            add_agent!(Agent0, model)
            id += 1
        end
        for i in 1:choices[2]
            add_agent!(Agent1, model, (0, 0))
            id +=1
        end
        for i in 1:choices[3]
            add_agent!(Agent2, model, 5.0)
            id += 1
        end
        for i in 1:choices[4]
            add_agent!(Agent3, model, (0, 0), 5.0)
            id += 1
        end
        return model
    end

    # standard scheduler
    model = init_mixed_model2()
    @test sort!(collect(abmscheduler(model)(model))) == 1:12

    # shuffling types scheduler
    Random.seed!(12)
    model = init_mixed_model2(scheduler = Schedulers.ByType(true, false, Union{Agent0,Agent1,Agent2,Agent3}))
    s1 = abmscheduler(model)(model)
    s1_types = unique([typeof(model[x]) for x in s1])
    s2 = abmscheduler(model)(model)
    s2_types = unique([typeof(model[x]) for x in s2])
    @test s1_types != s2_types
    @test count(model[id] isa Agent2 for id in abmscheduler(model)(model)) == 3
    c = begin
        x = 0; s = abmscheduler(model)(model)
        x += count(a -> a == Agent0, typeof(model[id]) for id in s)
        x += count(a -> a == Agent1, typeof(model[id]) for id in s)
        x += count(a -> a == Agent2, typeof(model[id]) for id in s)
        x += count(a -> a == Agent3, typeof(model[id]) for id in s)
    end
    @test c == 12

    # NOT shuffling types scheduler
    Random.seed!(12)
    model = init_mixed_model2(scheduler = Schedulers.ByType(false, false, Union{Agent0,Agent1,Agent2,Agent3}))
    s1 = abmscheduler(model)(model)
    s2 = abmscheduler(model)(model)
    @test unique([typeof(model[id]) for id in s1]) == unique([typeof(model[id]) for id in s2])

    # Not shuffling types, but shuffling agents
    Random.seed!(12)
    model = init_mixed_model2(scheduler = Schedulers.ByType(false, true, Union{Agent0,Agent1,Agent2,Agent3}))
    s1 = collect(abmscheduler(model)(model))
    s2 = collect(abmscheduler(model)(model))
    @test [typeof(model[id]) for id in s1] == [typeof(model[id]) for id in s2]
    # here we actually check whether agents of same type are shuffled
    @test model[s1[1]].id ≠ model[s2[1]] || model[s1[2]].id ≠ model[s2[2]]

    # Explicit order of types scheduling
    Random.seed!(12)
    model =
        StandardABM(Union{Agent1,Agent0}, scheduler = Schedulers.ByType((Agent1, Agent0), true), warn = false, warn_deprecation = false)
    for id in 1:3
        add_agent!(Agent1, model, (0, 0))
    end
    for id in 4:6
        add_agent!(Agent0, model)
    end
    s = collect(abmscheduler(model)(model))
    @test [typeof(model[id]) for id in s] ==
            [Agent1, Agent1, Agent1, Agent0, Agent0, Agent0]
    @test all(x -> x < 4, s[1:3])
    @test all(x -> x > 3, s[4:6])
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
function init_mixed_model(choices = [3, 3, 3, 3]; scheduler = Schedulers.fastest)
    model = StandardABM(Union{Agent0,Agent1,Agent2,Agent3}, scheduler = scheduler, rng = MersenneTwister(48),
                        warn = false, warn_deprecation = false)
    atypes = (Agent0,Agent1,Agent2,Agent3)
    id = 1
    for i in 1:choices[1]
        add_agent!(Agent0, model)
        id += 1
    end
    for i in 1:choices[2]
        add_agent!(Agent1, model, (0, 0))
        id +=1
    end
    for i in 1:choices[3]
        add_agent!(Agent2, model, 5.0)
        id += 1
    end
    for i in 1:choices[4]
        add_agent!(Agent3, model, (0, 0), 5.0)
        id += 1
    end
    return model
end

@testset "Mixed Scheduler" begin
    # standard scheduler
    model = init_mixed_model()
    @test sort!(collect(abmscheduler(model)(model))) == 1:12

    # shuffling types scheduler
    Random.seed!(12)
    model = init_mixed_model(scheduler = Schedulers.ByType(true, false, Union{Agent0,Agent1,Agent2,Agent3}))
    s1 = collect(abmscheduler(model)(model))
    s2 = collect(abmscheduler(model)(model))
    @test unique([typeof(model[id]) for id in s1]) != unique([typeof(model[id]) for id in s2])
    @test count(model[id] isa Agent2 for id in abmscheduler(model)(model)) == 3
    c = begin
        x = 0; s = abmscheduler(model)(model)
        x += count(a -> a == Agent0, typeof(model[id]) for id in s)
        x += count(a -> a == Agent1, typeof(model[id]) for id in s)
        x += count(a -> a == Agent2, typeof(model[id]) for id in s)
        x += count(a -> a == Agent3, typeof(model[id]) for id in s)
    end
    @test c == 12

    # NOT shuffling types scheduler
    Random.seed!(12)
    model = init_mixed_model(scheduler = Schedulers.ByType(false, false, Union{Agent0,Agent1,Agent2,Agent3}))
    s1 = abmscheduler(model)(model)
    s2 = abmscheduler(model)(model)
    @test unique([typeof(model[id]) for id in s1]) == unique([typeof(model[id]) for id in s2])

    # Not shuffling types, but shuffling agents
    Random.seed!(12)
    model = init_mixed_model(scheduler = Schedulers.ByType(false, true, Union{Agent0,Agent1,Agent2,Agent3}))
    s1 = collect(abmscheduler(model)(model))
    s2 = collect(abmscheduler(model)(model))
    @test [typeof(model[id]) for id in s1] == [typeof(model[id]) for id in s2]
    # here we actually check whether agents of same type are shuffled
    @test model[s1[1]].id ≠ model[s2[1]].id || model[s1[2]].id ≠ model[s2[2]].id

    # Explicit order of types scheduling
    Random.seed!(12)
    model =
        StandardABM(Union{Agent1,Agent0}, scheduler = Schedulers.ByType((Agent1, Agent0), true), warn = false, warn_deprecation = false)
    for id in 1:3
        add_agent!(Agent1, model, (0, 0))
    end
    for id in 4:6
        add_agent!(Agent0, model)
    end
    s = collect(abmscheduler(model)(model))
    @test [typeof(model[id]) for id in s] ==
          [Agent1, Agent1, Agent1, Agent0, Agent0, Agent0]
    @test all(x -> x < 4, s[1:3])
    @test all(x -> x > 3, s[4:6])
end

@testset "Scheduler as struct" begin
    mutable struct MyScheduler
        n::Int # step number
        w::Float64
    end
    function (ms::MyScheduler)(model::ABM)
        ms.n += 1 # increment internal counter by 1 for each step
        if ms.n < 5
            return allids(model) # order doesn't matter in this case
        else
            ids = collect(allids(model))
            # filter all ids whose agents have `w` less than some amount
            filter!(id -> model[id].weight > ms.w, ids)
            return ids
        end
    end

    model = StandardABM(Agent2;
        properties = Dict{Int, Bool}(),
        scheduler = MyScheduler(0, 5.0),
        warn_deprecation = false
    )
    for w in 1.0:10.0
        add_agent!(model, w)
    end
    for i in 1:10
        ids = sort!(collect(abmscheduler(model)(model)))
        if i < 5
            @test ids == 1:10
        else
            @test ids == 6:10
        end
    end
end

end
