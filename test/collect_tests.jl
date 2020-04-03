Random.seed!(267)

@testset "Aggregate Collections" begin
    model = ABM(Agent3, GridSpace((10,10)))
    add_agent!((4,3), model, rand())
    add_agent!((7,5), model, rand())
    add_agent!((2,9), model, rand())

    df = Agents.collect_agent_data(model, [:weight], 1)
    # Expecting weight values of all three agents. ID and step included.
    @test size(df) == (3,3)
    @test names(df) == [:id, :weight, :step]
    @test mean(df[!, :weight]) ≈ 0.3917615139
    df = Agents.collect_agent_data(model, Dict(:weight => [mean]), 1)
    # Activate aggregation. Weight column is expected to be one value for this step,
    # renamed mean(weight). ID is meaningless and will therefore be dropped.
    @test size(df) == (1,2)
    @test names(df) == [:step, Symbol("mean(weight)")]
    @test df[1, Symbol("mean(weight)")] ≈ 0.3917615139

    # Add a function as a property
    x_position(agent) = first(agent.pos)
    df = Agents.collect_agent_data(model, [:weight, x_position], 1)
    @test size(df) == (3,4)
    @test names(df) == [:id, :weight, :x_position, :step]
    @test mean(df[!, :x_position]) ≈ 4.3333333
    df = Agents.collect_agent_data(model, Dict(:weight => [mean], x_position => [mean]), 1)
    @test size(df) == (1,3)
    # Order of the table is not guaranteed with this call, so we check all names are extant
    @test all(name -> name in [:step, Symbol("mean(x_position)"), Symbol("mean(weight)")], names(df))
    @test df[1, Symbol("mean(x_position)")] ≈ 4.3333333
end
