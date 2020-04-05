function initialize()
    Random.seed!(267)
    model = ABM(Agent3, GridSpace((10,10));
                properties = Dict(:year => 0, :tick => 0, :flag => false))
    add_agent!((4,3), model, rand())
    add_agent!((7,5), model, rand())
    add_agent!((2,9), model, rand())
    return model
end

function agent_step!(agent, model)
    if rand() < 0.1
        agent.weight += 0.05
    end
    if model.tick%365 == 0
        agent.weight *= 2
    end
end
function model_step!(model)
    model.tick += 1
    model.flag = rand(Bool)
    if model.tick%365 == 0
        model.year += 1
    end
end

x_position(agent) = first(agent.pos)

model = initialize()

@testset "Aggregate Collections" begin
    props = [:weight]
    df = init_agent_dataframe(model, props)
    collect_agent_data!(df, model, props, 1)
    # Expecting weight values of all three agents. ID and step included.
    @test size(df) == (3,3)
    @test names(df) == [:step, :id, :weight]
    @test mean(df[!, :weight]) ≈ 0.3917615139

    props = [(:weight, mean)]
    df = init_agent_dataframe(model, props)
    collect_agent_data!(df, model, props, 1)
    # Activate aggregation. Weight column is expected to be one value for this step,
    # renamed mean(weight). ID is meaningless and will therefore be dropped.
    @test size(df) == (1,2)
    @test names(df) == [:step, Symbol("mean(weight)")]
    @test df[1, Symbol("mean(weight)")] ≈ 0.3917615139

    # Add a function as a property
    props = [:weight, x_position]
    df = init_agent_dataframe(model, props)
    collect_agent_data!(df, model, props, 1)
    @test size(df) == (3,4)
    @test names(df) == [:step, :id, :weight, :x_position]
    @test mean(df[!, :x_position]) ≈ 4.3333333

    props = [(:weight, mean), (x_position, mean)]
    df = init_agent_dataframe(model, props)
    collect_agent_data!(df, model, props, 1)
    @test size(df) == (1,3)
    @test names(df) == [:step, Symbol("mean(weight)"), Symbol("mean(x_position)")]
    @test df[1, Symbol("mean(x_position)")] ≈ 4.3333333
end

@testset "High-level API for Collections" begin
    # Extract data from the model every year for five years.
    # Requirements include the average `weight` for all agents and the current flag
    # within the model.
    # TODO: use the latest API, in particular when_model
    each_year(model, step) = step%365 == 0
    agent_data, model_data = run!(model, agent_step!, model_step!, 365*5;
                                  when=each_year, model_properties = [:flag, :year],
                                  agent_properties = [(:weight, mean)])

    @test size(agent_data) == (5,2)
    @test names(agent_data) == [:step, Symbol("mean(weight)")]
    @test maximum(agent_data[!, :step]) == 1460

    @test size(model_data) == (5,3)
    @test names(model_data) == [:step, :flag, :year]
    @test maximum(model_data[!, :step]) == 1460
end

@testset "Low-level API for Collections" begin
    # Generate three separate dataframes using the low level API.
    # User controls the evolution, as well as the identity of each `step`.
    # Note in this example daily data are labelled with a daily `step`,
    # and yearly data with a yearly `step`.
    model = initialize()
    model_props = [:flag, :year]
    agent_agg = [(:weight, mean)]
    agent_props = [:weight]
    daily_model_data = init_model_dataframe(model, model_props)
    daily_agent_aggregate = init_agent_dataframe(model, agent_agg)
    yearly_agent_data = init_agent_dataframe(model, agent_props)

    for year in 1:5
        for day in 1:365
            step!(model, agent_step!, model_step!, 1)
            collect_model_data!(daily_model_data, model, model_props, day*year)
            collect_agent_data!(daily_agent_aggregate, model, agent_agg, day*year)
        end
        collect_agent_data!(yearly_agent_data, model, agent_props, year)
    end

    @test size(daily_model_data) == (1825,3)
    @test names(daily_model_data) == [:step, :flag, :year]
    @test maximum(daily_model_data[!, :step]) == 1825

    @test size(daily_agent_aggregate) == (1825,2)
    @test names(daily_agent_aggregate) == [:step, Symbol("mean(weight)")]
    @test maximum(daily_agent_aggregate[!, :step]) == 1825

    @test size(yearly_agent_data) == (15,3)
    @test names(yearly_agent_data) == [:step, :id, :weight]
    @test maximum(yearly_agent_data[!, :step]) == 5
end

