using Random
using Agents, Test

@testset "Random Number Generation" begin
    model = ABM(Agent2)
    @test abmrng(model) == Random.default_rng()
    rng = StableRNG(42)
    rng0 = StableRNG(42)

    model = ABM(Agent1, GridSpace((3,3)); rng)
    agent = Agent1(1, (1,1))
    add_agent_pos!(agent, model)
    agent = Agent1(2, (1,1))
    add_agent_single!(agent, model)
    # Test that model rng pool was used
    @test abmrng(model) ≠ rng0
    @test agent.pos == (2,1)

    model = ABM(Agent2; rng = RandomDevice())
    @test_throws MethodError seed!(abmrng(model), 64)
end

@testset "sample!" begin
    rng = StableRNG(42)
    model = ABM(Agent2)
    for i in 1:20
        add_agent!(model, rand(abmrng(model)) / rand(abmrng(model)))
    end
    allweights = [i.weight for i in values(model.agents)]
    mean_weights = sum(allweights) / length(allweights)
    sample!(model, 12, :weight)
    @test nagents(model) == 12
    allweights = [i.weight for i in values(model.agents)]
    mean_weights_new = sum(allweights) / length(allweights)
    @test mean_weights_new > mean_weights
    sample!(model, 40, :weight)
    @test nagents(model) == 40
    allweights = [i.weight for i in values(model.agents)]
    mean_weights_new = sum(allweights) / length(allweights)
    @test mean_weights_new > mean_weights

    Random.seed!(6459)
    model2 = ABM(Agent3, GridSpace((10, 10)))
    for i in 1:20
        add_agent_single!(Agent3(i, (1, 1), rand(model2.rng) / rand(model2.rng)), model2)
    end
    @test sample!(model2, 10) === nothing
    @test sample!(model2, 10, :weight) === nothing
    allweights = [i.weight for i in values(model2.agents)]
    mean_weights = sum(allweights) / length(allweights)
    sample!(model2, 12, :weight)
    @test nagents(model2) == 12
    allweights = [i.weight for i in values(model2.agents)]
    mean_weights_new = sum(allweights) / length(allweights)
    @test mean_weights_new > mean_weights

    sample!(model2, 40, :weight)
    @test nagents(model2) == 40

    Random.seed!(6459)
    #Guarantee all starting weights are unique
    model3 = ABM(Agent2)
    while true
        for i in 1:20
            add_agent!(model3, rand(model3.rng) / rand(model3.rng))
        end
        allweights = [i.weight for i in values(model3.agents)]
        allunique(allweights) && break
    end
    # Cannot draw 50 samples out of a pool of 20 without replacement
    @test_throws ErrorException sample!(model3, 50, :weight; replace = false)
    sample!(model3, 15, :weight; replace = false)
    allweights = [i.weight for i in values(model3.agents)]
    @test allunique(allweights)
    model3 = ABM(Agent2)
    while true
        for i in 1:20
            add_agent!(model3, rand(model3.rng) / rand(model3.rng))
        end
        allweights = [i.weight for i in values(model3.agents)]
        allunique(allweights) && break
    end
    sample!(model3, 100, :weight; replace = true)
    allweights = [i.weight for i in values(model3.agents)]
    @test !allunique(allweights)
end

@testset "random agent" begin
    space = GridSpace((10, 10))
    model = ABM(Union{Daisy,Land}, space; warn = false)
    fill_space!(Daisy, model, "black")
    add_agent!(Land(999, (1, 1), 999), model)

    a = random_agent(model)
    @test typeof(a) <: Union{Daisy,Land}

    c1(a) = a isa Land
    a = random_agent(model, c1)
    @test a.id == 999

    c2(a) = a isa Float64
    a = random_agent(model, c2)
    @test isnothing(a)
end
