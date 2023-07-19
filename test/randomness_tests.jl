using Agents, Test
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
    model = ABM(Agent2; rng = rng)
    for i in 1:20
        add_agent!(model, rand(abmrng(model2)))
    end
    allweights = [i.weight for i in allagents(model)]
    mean_weights = sum(allweights) / length(allweights)
    sample!(model, 12, :weight)
    @test nagents(model) == 12
    allweights = [i.weight for i in allagents(model)]
    mean_weights_new = sum(allweights) / length(allweights)
    @test mean_weights_new > mean_weights

    model2 = ABM(Agent2; rng = rng)
    while true
        for i in 1:20
            add_agent!(model2, rand(abmrng(model2)) / rand(abmrng(model2)))
        end
        allweights = [i.weight for i in allagents(model3)]
        allunique(allweights) && break
    end
    # Cannot draw 50 samples out of a pool of 20 without replacement
    @test_throws ErrorException sample!(model2, 50, :weight; replace = false)
    sample!(model2, 15, :weight; replace = false)
    allweights = [i.weight for i in allagents(model3)]
    @test allunique(allweights)

    model3 = ABM(Agent2; rng = rng)
    while true
        for i in 1:20
            add_agent!(model3, rand(abmrng(model3)) / rand(abmrng(model3)))
        end
        allweights = [i.weight for i in allagents(model3)]
        allunique(allweights) && break
    end
    sample!(model3, 100, :weight; replace = true)
    allweights = [i.weight for i in allagents(model3)]
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
