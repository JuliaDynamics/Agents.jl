@testset "CSV" begin
    function Models.HKAgent(id, op)
        return Models.HKAgent(id, op, op, -1)
    end
    function Models.HKAgent(; id = -1, op1 = -1, op2 = -1, op3 = -1)
        return Models.HKAgent(id, op1, op2, op3)
    end
    
    function Models.Fighter(id, p1, p2, p3, has, cap, shape)
        return Models.Fighter(id, (p1, p2, p3), has, cap, shape)
    end

    @agent Foo GridAgent{2} begin end
    @agent Bar GridAgent{2} begin end

    model = ABM(Union{Foo,Bar}, GridSpace((5,5)); warn = false)
    
    @test_throws AssertionError AgentsIO.populate_from_csv!(model, "test.csv")

    model, _ = Models.hk(numagents = 10)
    empty_model, _ = Models.hk(numagents = 0)

    AgentsIO.dump_to_csv("test.csv", allagents(model))
    
    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 4
    end
    
    AgentsIO.populate_from_csv!(empty_model, "test.csv")

    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    genocide!(empty_model)
    AgentsIO.populate_from_csv!(empty_model, "test.csv", Models.HKAgent, Dict(:id => 1, :op1 => 3, :op2 => 2))
    
    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    AgentsIO.dump_to_csv("test.csv", Models.HKAgent[model[i] for i in 1:nagents(model)], [:old_opinion])

    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 1
    end

    genocide!(empty_model)
    AgentsIO.populate_from_csv!(empty_model, "test.csv"; row_number_is_id = true)

    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    genocide!(empty_model)
    AgentsIO.populate_from_csv!(empty_model, "test.csv", Models.HKAgent, Dict(:op1 => 1, :op2 => 1); row_number_is_id = true)
    
    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    AgentsIO.dump_to_csv("test.csv", allagents(model), [:id, :old_opinion])

    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 2
    end

    genocide!(empty_model)
    AgentsIO.populate_from_csv!(empty_model, "test.csv")

    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    model, _ = Models.battle(; fighters = 10)
    empty_model, _ = Models.battle(; fighters = 0)

    AgentsIO.dump_to_csv("test.csv", allagents(model))
    AgentsIO.populate_from_csv!(empty_model, "test.csv")

    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].pos == empty_model[i].pos for i in allids(model))
    @test all(model[i].has_prisoner == empty_model[i].has_prisoner for i in allids(model))
    @test all(model[i].capture_time == empty_model[i].capture_time for i in allids(model))
    @test all(model[i].shape == empty_model[i].shape for i in allids(model))
    
    rm("test.csv")
end
    