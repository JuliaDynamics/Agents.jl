@testset "CSV" begin
    function Models.HKAgent(id, op)
        return Models.HKAgent(id, op, op, -1)
    end
    function Models.HKAgent(; id = -1, op1 = -1, op2 = -1, op3 = -1)
        return Models.HKAgent(id, op1, op2, op3)
    end

    model, _ = Models.hk()
    empty_model, _ = Models.hk()

    Agents.ModelIO.dump_to_csv("test.csv", allagents(model))
    
    open("test.csv", "r") do f
        @test length(split(readline(f), ',')) == 4
    end
    
    genocide!(empty_model)
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

    rm("test.csv")
end
    