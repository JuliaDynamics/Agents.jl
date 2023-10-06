@testset "CSV" begin
    mutable struct HKAgent <: AbstractAgent
        id::Int
        old_opinion::Float64
        new_opinion::Float64
        previous_opinion::Float64
    end

    function hk(; numagents = 100, ϵ = 0.2)
        model = StandardABM(HKAgent, scheduler = Schedulers.fastest, properties = Dict(:ϵ => ϵ), warn_deprecation = false)
        for i in 1:numagents
            o = rand(abmrng(model))
            add_agent!(model, o, o, -1)
        end
        return model
    end

    HKAgent(id, op) = HKAgent(id, op, op, -1)
    HKAgent(; id = -1, op1 = -1, op2 = -1, op3 = -1) = HKAgent(id, op1, op2, op3)

    Models.SchellingAgent(id, p1, p2, mood, group) = Models.SchellingAgent(id, (p1, p2), mood, group)

    @agent struct Foo(GridAgent{2})
    end
    @agent struct Bar(GridAgent{2})
    end

    model = StandardABM(Union{Foo,Bar}, GridSpace((5,5)); warn = false, warn_deprecation = false)

    @test_throws AssertionError AgentsIO.populate_from_csv!(model, "test.csv")

    model = hk(; numagents = 10)
    empty_model = hk(; numagents = 0)

    AgentsIO.dump_to_csv("test.csv", allagents(model))

    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 4
    end

    AgentsIO.populate_from_csv!(empty_model, "test.csv")

    @test nagents(empty_model) == nagents(model)
    @test Set(allids(empty_model)) == Set(allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    remove_all!(empty_model)
    AgentsIO.populate_from_csv!(empty_model, "test.csv", HKAgent, Dict(:id => 1, :op1 => 3, :op2 => 2))

    @test nagents(empty_model) == nagents(model)
    @test Set(allids(empty_model)) == Set(allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    AgentsIO.dump_to_csv("test.csv", HKAgent[model[i] for i in 1:nagents(model)], [:old_opinion])

    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 1
    end

    remove_all!(empty_model)
    AgentsIO.populate_from_csv!(empty_model, "test.csv"; row_number_is_id = true)

    @test nagents(empty_model) == nagents(model)
    @test Set(allids(empty_model)) == Set(allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    remove_all!(empty_model)
    AgentsIO.populate_from_csv!(empty_model, "test.csv", HKAgent, Dict(:op1 => 1, :op2 => 1); row_number_is_id = true)

    @test nagents(empty_model) == nagents(model)
    @test Set(allids(empty_model)) == Set(allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    AgentsIO.dump_to_csv("test.csv", allagents(model), [:id, :old_opinion])

    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 2
    end

    remove_all!(empty_model)
    AgentsIO.populate_from_csv!(empty_model, "test.csv")

    @test nagents(empty_model) == nagents(model)
    @test Set(allids(empty_model)) == Set(allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    model = Models.schelling(; numagents = 10)
    empty_model = Models.schelling(; numagents = 0)

    AgentsIO.dump_to_csv("test.csv", allagents(model))
    AgentsIO.populate_from_csv!(empty_model, "test.csv")

    @test nagents(empty_model) == nagents(model)
    @test Set(allids(empty_model)) == Set(allids(model))
    @test all(model[i].pos == empty_model[i].pos for i in allids(model))
    @test all(model[i].mood == empty_model[i].mood for i in allids(model))
    @test all(model[i].group == empty_model[i].group for i in allids(model))

    rm("test.csv")
end

