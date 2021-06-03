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

    model, _ = Models.hk(numagents = 10)
    empty_model, _ = Models.hk(numagents = 0)

    Agents.ModelIO.dump_to_csv("test.csv", allagents(model))
    
    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 4
    end
    
    Agents.ModelIO.populate_from_csv!(empty_model, "test.csv", Models.HKAgent)

    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    genocide!(empty_model)
    Agents.ModelIO.populate_from_csv!(empty_model, "test.csv", Models.HKAgent, Dict(:id => 1, :op1 => 3, :op2 => 2))

    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    Agents.ModelIO.dump_to_csv("test.csv", allagents(model), [:id, :old_opinion])

    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 2
    end

    genocide!(empty_model)
    Agents.ModelIO.populate_from_csv!(empty_model, "test.csv", Models.HKAgent)

    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].old_opinion == empty_model[i].old_opinion for i in allids(model))
    @test all(model[i].new_opinion == empty_model[i].new_opinion for i in allids(model))
    @test all(model[i].previous_opinion == empty_model[i].previous_opinion for i in allids(model))

    model, _ = Models.battle(; fighters = 10)
    empty_model, _ = Models.battle(; fighters = 0)

    Agents.ModelIO.dump_to_csv("test.csv", allagents(model))
    Agents.ModelIO.populate_from_csv!(empty_model, "test.csv", Models.Fighter)

    @test nagents(empty_model) == nagents(model)
    @test all(haskey(empty_model.agents, i) for i in allids(model))
    @test all(model[i].pos == empty_model[i].pos for i in allids(model))
    @test all(model[i].has_prisoner == empty_model[i].has_prisoner for i in allids(model))
    @test all(model[i].capture_time == empty_model[i].capture_time for i in allids(model))
    @test all(model[i].shape == empty_model[i].shape for i in allids(model))
    
    rm("test.csv")
end
    