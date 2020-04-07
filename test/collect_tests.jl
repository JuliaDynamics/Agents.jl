function initialize()
    Random.seed!(267)
    model = ABM(
        Agent3,
        GridSpace((10, 10));
        properties = Dict(:year => 0, :tick => 0, :flag => false),
    )
    add_agent!((4, 3), model, rand())
    add_agent!((7, 5), model, rand())
    add_agent!((2, 9), model, rand())
    return model
end

function agent_step!(agent, model)
    if rand() < 0.1
        agent.weight += 0.05
    end
    if model.tick % 365 == 0
        agent.weight *= 2
    end
end
function model_step!(model)
    model.tick += 1
    model.flag = rand(Bool)
    if model.tick % 365 == 0
        model.year += 1
    end
end

x_position(agent) = first(agent.pos)
model = initialize()

@testset "DataFrame init" begin
    props = [:weight]
    @test sprint(show, "text/csv", describe(init_agent_dataframe(model, props), :eltype)) == "\"variable\",\"eltype\"\n\"step\",\"Int64\"\n\"id\",\"Int64\"\n\"weight\",\"Float64\"\n"
    props = [:year]
    @test sprint(show, "text/csv", describe(init_model_dataframe(model, props), :eltype)) == "\"variable\",\"eltype\"\n\"step\",\"Int64\"\n\"year\",\"Int64\"\n"
end

@testset "aggname" begin
    @test aggname(:weight, mean) == Symbol("mean(weight)")
    @test aggname(x_position, length) == Symbol("length(x_position)")
end

@testset "Aggregate Collections" begin
    props = [:weight]
    df = init_agent_dataframe(model, props)
    collect_agent_data!(df, model, props, 1)
    # Expecting weight values of all three agents. ID and step included.
    @test size(df) == (3, 3)
    @test names(df) == [:step, :id, :weight]
    @test mean(df[!, :weight]) ≈ 0.3917615139

    props = [(:weight, mean)]
    df = init_agent_dataframe(model, props)
    collect_agent_data!(df, model, props, 1)
    # Activate aggregation. Weight column is expected to be one value for this step,
    # renamed mean(weight). ID is meaningless and will therefore be dropped.
    @test size(df) == (1, 2)
    @test names(df) == [:step, Symbol("mean(weight)")]
    @test df[1, Symbol("mean(weight)")] ≈ 0.3917615139

    # Add a function as a property
    props = [:weight, x_position]
    df = init_agent_dataframe(model, props)
    collect_agent_data!(df, model, props, 1)
    @test size(df) == (3, 4)
    @test names(df) == [:step, :id, :weight, :x_position]
    @test mean(df[!, :x_position]) ≈ 4.3333333

    props = [(:weight, mean), (x_position, mean)]
    df = init_agent_dataframe(model, props)
    collect_agent_data!(df, model, props, 1)
    @test size(df) == (1, 3)
    @test names(df) == [:step, Symbol("mean(weight)"), Symbol("mean(x_position)")]
    @test df[1, Symbol("mean(x_position)")] ≈ 4.3333333
end

@testset "High-level API for Collections" begin
    # Extract data from the model every year for five years,
    # with the average `weight` of all agents every six months.
    each_year(model, step) = step % 365 == 0
    six_months(model, step) = step % 182 == 0
    agent_data, model_data = run!(
        model,
        agent_step!,
        model_step!,
        365 * 5;
        when_model = each_year,
        when = six_months,
        model_properties = [:flag, :year],
        agent_properties = [(:weight, mean)],
    )

    @test size(agent_data) == (11, 2)
    @test names(agent_data) == [:step, Symbol("mean(weight)")]
    @test maximum(agent_data[!, :step]) == 1820

    @test size(model_data) == (5, 3)
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
            collect_model_data!(daily_model_data, model, model_props, day * year)
            collect_agent_data!(daily_agent_aggregate, model, agent_agg, day * year)
        end
        collect_agent_data!(yearly_agent_data, model, agent_props, year)
    end

    @test size(daily_model_data) == (1825, 3)
    @test names(daily_model_data) == [:step, :flag, :year]
    @test maximum(daily_model_data[!, :step]) == 1825

    @test size(daily_agent_aggregate) == (1825, 2)
    @test names(daily_agent_aggregate) == [:step, Symbol("mean(weight)")]
    @test maximum(daily_agent_aggregate[!, :step]) == 1825

    @test size(yearly_agent_data) == (15, 3)
    @test names(yearly_agent_data) == [:step, :id, :weight]
    @test maximum(yearly_agent_data[!, :step]) == 5
end

n = 10
parameters = Dict(
    :f => [0.05, 0.07],
    :d => [0.6, 0.7, 0.8],
    :p => 0.01,
    :griddims => (20, 20),
    :seed => 2,
)
@testset "Parameter Scan" begin
    agent_properties = [(:status, length), (:status, count)]
    data, _ = paramscan(
        parameters,
        forest_initiation;
        n = n,
        agent_step! = dummystep,
        model_step! = forest_step!,
        agent_properties = agent_properties,
        progress = false,
    )
    # 6 is the number of combinations of changing params
    @test size(data) == (n * 6, 5)
    data, _ = paramscan(
        parameters,
        forest_initiation;
        n = n,
        agent_step! = dummystep,
        model_step! = forest_step!,
        include_constants = true,
        agent_properties = agent_properties,
        progress = false,
    )
    # 6 is the number of combinations of changing params,
    # 8 is 5+3, where 3 is the number of constant parameters
    @test size(data) == (n * 6, 8)

    agent_properties = [:status]
    data, _ = paramscan(
        parameters,
        forest_initiation;
        n = n,
        agent_step! = dummystep,
        model_step! = forest_step!,
        agent_properties = agent_properties,
        progress = false,
    )
    @test unique(data.step) == 0:9
    @test unique(data.f) == [0.05, 0.07]
    @test unique(data.d) == [0.6, 0.7, 0.8]
end

@testset "Parameter Scan with replicates" begin
    agent_properties = [(:status, length), (:status, count)]
    data, _ = paramscan(
        parameters,
        forest_initiation;
        n = n,
        agent_step! = dummystep,
        model_step! = forest_step!,
        replicates = 3,
        agent_properties = agent_properties,
        progress = false,
    )
    # the first 6 is the number of combinations of changing params
    @test size(data) == ((n * 6) * 3, 6)
end

@testset "Issue 179 fix" begin
    # only ids sorted, not properties
    model = ABM(Agent2)
    for i = 1:5
        add_agent!(model, i * 0.2)
    end
    data, _ = run!(model, dummystep, 2; agent_properties = [:weight])
    @test data[1, :id] == 1 && data[1, :weight] ≈ 0.2
    @test data[3, :id] == 3 && data[3, :weight] ≈ 0.6
    @test data[6, :id] == 1 && data[6, :weight] ≈ 0.2
end

