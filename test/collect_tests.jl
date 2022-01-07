@testset "DataCollection" begin
    mutable struct Nested
        data::Vector{Float64}
    end

    function initialize()
        model = ABM(
            Agent3,
            GridSpace((10, 10));
            properties = Dict(
                :year => 0,
                :tick => 0,
                :flag => false,
                :container => Float64[],
                :deep => Nested([20.0, 52.1]),
            ),
        )
        add_agent!((4, 3), model, 0.1)
        add_agent!((7, 5), model, 0.35)
        add_agent!((2, 9), model, 0.67)
        return model
    end

    function agent_step!(agent, model)
        agent.weight += 0.05
        if model.tick % 365 == 0
            agent.weight *= 2
        end
    end
    function model_step!(model)
        model.tick += 1
        model.flag = !model.flag
        if model.tick % 365 == 0
            model.year += 1
            model.deep.data[1] += 0.5
        end
    end

    x_position(agent) = first(agent.pos)
    model = initialize()

    @testset "DataFrame init" begin
        @test init_agent_dataframe(model, nothing) == DataFrame()
        @test collect_agent_data!(DataFrame(), model, nothing, 1) == DataFrame()

        @test init_model_dataframe(model, nothing) == DataFrame()
        @test collect_model_data!(DataFrame(), model, nothing, 1) == DataFrame()

        props = [:weight]
        @test sprint(
            show,
            "text/csv",
            describe(init_agent_dataframe(model, props), :eltype),
        ) ==
              "\"variable\",\"eltype\"\n\"step\",\"Int64\"\n\"id\",\"Int64\"\n\"weight\",\"Float64\"\n"
        props = [:year]
        @test sprint(
            show,
            "text/csv",
            describe(init_model_dataframe(model, props), :eltype),
        ) == "\"variable\",\"eltype\"\n\"step\",\"Int64\"\n\"year\",\"Int64\"\n"

        @test_throws ErrorException init_agent_dataframe(model, [:UNKNOWN])
    end

    @testset "dataname" begin
        adata = [(:weight, mean), (x_position, length)]
        @test dataname(:weight) == "weight"
        @test dataname((:weight, mean)) == "mean_weight"
        @test dataname(adata[2]) == "length_x_position"
        @test dataname((x_position, length)) == "length_x_position"
        ypos(a) = a.pos[2] > 5
        @test dataname((x_position, length, ypos)) == "length_x_position_ypos"

        funcs = Vector{Function}(undef, 2)
        for i in 1:length(funcs)
            inline_func(x) = i * x
            funcs[i] = inline_func
        end
        @test dataname(funcs[2]) == "inline_func_i=2"
    end

    @testset "Aggregate Collections" begin
        props = [:weight]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props, 1)
        # Expecting weight values of all three agents. ID and step included.
        @test size(df) == (3, 3)
        @test propertynames(df) == [:step, :id, :weight]
        @test mean(df[!, :weight]) ≈ 0.37333333333

        props = [(:weight, mean)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props, 1)
        # Activate aggregation. Weight column is expected to be one value for this step,
        # renamed mean(weight). ID is meaningless and will therefore be dropped.
        @test size(df) == (1, 2)
        @test propertynames(df) == [:step, :mean_weight]
        @test df[1, dataname((:weight, mean))] ≈ 0.37333333333

        # Add a function as a property
        props = [:weight, x_position]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props, 1)
        @test size(df) == (3, 4)
        @test propertynames(df) == [:step, :id, :weight, :x_position]
        @test mean(df[!, :x_position]) ≈ 4.3333333

        props = [(:weight, mean), (x_position, mean)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props, 1)
        @test size(df) == (1, 3)
        @test propertynames(df) == [:step, :mean_weight, :mean_x_position]
        @test df[1, dataname(props[2])] ≈ 4.3333333

        xtest(agent) = agent.pos[1] > 5
        ytest(agent) = agent.pos[2] > 5

        props = [(:weight, mean, ytest)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props, 1)
        @test size(df) == (1, 2)
        @test propertynames(df) == [:step, :mean_weight_ytest]
        @test df[1, dataname((:weight, mean, ytest))] ≈ 0.67

        props = [(:weight, mean), (:weight, mean, ytest)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props, 1)
        @test size(df) == (1, 3)
        @test propertynames(df) == [:step, :mean_weight, :mean_weight_ytest]
        @test df[1, dataname(props[1])] ≈ 0.37333333333
        @test df[1, dataname(props[2])] ≈ 0.67

        props = [(:weight, mean, xtest), (:weight, mean, ytest)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props, 1)
        @test size(df) == (1, 3)
        @test propertynames(df) == [:step, :mean_weight_xtest, :mean_weight_ytest]
        @test df[1, dataname(props[1])] ≈ 0.35
        @test df[1, dataname(props[2])] ≈ 0.67
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
            mdata = [:flag, :year],
            adata = [(:weight, mean)],
        )

        @test size(agent_data) == (11, 2)
        @test propertynames(agent_data) == [:step, :mean_weight]
        @test maximum(agent_data[!, :step]) == 1820

        @test size(model_data) == (6, 3)
        @test propertynames(model_data) == [:step, :flag, :year]
        @test maximum(model_data[!, :step]) == 1825

        agent_data, model_data = run!(
            model,
            agent_step!,
            model_step!,
            365 * 5;
            when_model = [1, 365 * 5],
            when = false,
            mdata = [:flag, :year],
            adata = [(:weight, mean)],
        )
        @test size(agent_data) == (0, 2)
        @test size(model_data) == (2, 3)

        _, model_data = run!(
            model,
            agent_step!,
            model_step!,
            365 * 5;
            when_model = [1, 365 * 5],
            when = false,
            mdata = [:deep],
            obtainer = deepcopy,
        )
        @test model_data[1, :deep].data[1] < model_data[end, :deep].data[1]

        _, model_data = run!(
            model,
            agent_step!,
            model_step!,
            365 * 5;
            when_model = [365 * 5],
            when = false,
            mdata = [(m) -> (m.deep.data[i]) for i in 1:length(model.deep.data)],
        )
        @test Array{Float64,1}(model_data[1, 2:end]) == model.deep.data
    end

    @testset "Low-level API for Collections" begin
        # Generate three separate dataframes using the low level API.
        # User controls the evolution, as well as the identity of each `step`.
        # Note in this example daily data are labelled with a daily `step`,
        # and yearly data with a yearly `step`.
        model = initialize()
        model_props = [:flag, :year]
        function model_props_fn(model)
            flagfn(model) = model.flag
            yearfn(model) = model.year
            return [flagfn, yearfn]
        end
        agent_agg = [(:weight, mean)]
        agent_props = [:weight]
        daily_model_data = init_model_dataframe(model, model_props)
        daily_model_data_fn = init_model_dataframe(model, model_props_fn)
        daily_agent_aggregate = init_agent_dataframe(model, agent_agg)
        yearly_agent_data = init_agent_dataframe(model, agent_props)

        for year in 1:5
            for day in 1:365
                step!(model, agent_step!, model_step!, 1)
                collect_model_data!(daily_model_data, model, model_props, day * year)
                collect_model_data!(daily_model_data_fn, model, model_props_fn, day * year)
                collect_agent_data!(daily_agent_aggregate, model, agent_agg, day * year)
            end
            collect_agent_data!(yearly_agent_data, model, agent_props, year)
        end

        @test size(daily_model_data) == (1825, 3)
        @test propertynames(daily_model_data) == [:step, :flag, :year]
        @test maximum(daily_model_data[!, :step]) == 1825

        @test size(daily_model_data_fn) == (1825, 3)
        @test propertynames(daily_model_data_fn) == [:step, :flagfn, :yearfn]
        @test maximum(daily_model_data_fn[!, :step]) == 1825

        @test size(daily_agent_aggregate) == (1825, 2)
        @test propertynames(daily_agent_aggregate) == [:step, :mean_weight]
        @test maximum(daily_agent_aggregate[!, :step]) == 1825

        @test size(yearly_agent_data) == (15, 3)
        @test propertynames(yearly_agent_data) == [:step, :id, :weight]
        @test maximum(yearly_agent_data[!, :step]) == 5

        @test dummystep(model) === nothing
        @test dummystep(model[1], model) === nothing
        tick = model.tick
        step!(model, agent_step!, 1)
        @test tick == model.tick
        stop(m, s) = m.year == 6
        step!(model, agent_step!, model_step!, stop)
        @test model.tick == 365 * 6
        step!(model, agent_step!, model_step!, 1, false)
    end

    @testset "Mixed-ABM collections" begin
        model = ABM(Union{Agent3,Agent4}, GridSpace((10, 10)); warn = false)
        add_agent_pos!(Agent3(1, (6, 8), 54.65), model)
        add_agent_pos!(Agent4(2, (10, 7), 5), model)

        # Expect position type (both agents have it)
        props = [:pos]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (2, 4)
        @test propertynames(df) == [:step, :id, :agent_type, :pos]
        @test df[1, :pos] == model[1].pos
        @test df[2, :pos] == model[2].pos

        # Expect weight for Agent3, but missing for Agent4
        props = [:weight]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (2, 4)
        @test df[1, :weight] == model[1].weight
        @test ismissing(df[2, :weight])

        # Expect similar output, but using functions
        wpos(a) = a.pos[1] + a.weight
        props = [wpos]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (2, 4)
        @test df[1, :wpos] == model[1].pos[1] + model[1].weight
        @test ismissing(df[2, :wpos])

        # Expect similar output, but using anonymous accessor functions
        props = [(a) -> (a.pos[i] + a.weight) for i in 1:2]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (2, 5)
        @test df[1, dataname(props[1])] == model[1].pos[1] + model[1].weight
        @test ismissing(df[2, dataname(props[2])])

        add_agent_pos!(Agent3(3, (2, 4), 19.81), model)
        add_agent_pos!(Agent4(4, (4, 1), 3), model)

        props = [:pos, :weight, :p, wpos]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (4, 7)
        @test typeof(df.pos) <: Vector{Tuple{Int,Int}}
        @test typeof(df.weight) <: Vector{Union{Missing,Float64}}
        @test typeof(df.p) <: Vector{Union{Missing,Int}}
        @test typeof(df.wpos) <: Vector{Union{Missing,Float64}}

        # Expect something completely unknown to fail
        props = [:UNKNOWN]
        @test_throws ErrorException init_agent_dataframe(model, props)

        # Aggregates should behave in a similiar fashion
        pos1(a) = a.pos[1]
        props = [(:pos, length), (pos1, sum)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 3)
        @test typeof(df.length_pos) <: Vector{Int}
        @test df[1, :length_pos] == 4
        @test typeof(df.sum_pos1) <: Vector{Int}
        @test df[1, :sum_pos1] == 22

        # Expect aggregate to filter out Agent4's
        a3(a) = a isa Agent3
        props = [(pos1, sum, a3)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 2)
        @test typeof(df.sum_pos1_a3) <: Vector{Int}
        @test df[1, :sum_pos1_a3] == 8

        # When aggregating, missing data must be handled explicitly.
        props = [(:weight, sum)]
        df = init_agent_dataframe(model, props)
        @test_throws ErrorException collect_agent_data!(df, model, props)

        # Filtering out missings makes this work.
        props = [(:weight, sum, a3)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 2)
        @test typeof(df.sum_weight_a3) <: Vector{Float64}
        @test df[1, :sum_weight_a3] ≈ 74.46

        # Handle missmatches
        # In this example, weight exists in both agents, but they have different types
        mutable struct Agent3Int <: AbstractAgent
            id::Int
            pos::Dims{2}
            weight::Int
        end
        model = ABM(Union{Agent3,Agent3Int}, GridSpace((10, 10)); warn = false)
        add_agent_pos!(Agent3(1, (6, 8), 54.65), model)
        add_agent_pos!(Agent3Int(2, (10, 7), 5), model)
        add_agent_pos!(Agent3(3, (2, 4), 19.81), model)
        add_agent_pos!(Agent3Int(4, (4, 1), 3), model)

        props = [:weight]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (4, 4)
        @test typeof(df.weight) <: Vector{Union{Float64,Int}}

        # Expect a1.weight <: Float64, a2.weight <: Int64 to fail in aggregate
        props = [(:weight, sum)]
        @test_throws ErrorException init_agent_dataframe(model, props)

        # Promotion is the fix in this case
        fweight(a) = Float64(a.weight)
        props = [(fweight, sum)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 2)
        @test df[1, :sum_fweight] ≈ 82.46
    end

    @testset "Observers" begin
        model = initialize()
        model_props = [:container]
        model_data = init_model_dataframe(model, model_props)
        push!(model.container, 50.0)
        collect_model_data!(model_data, model, model_props, 0; obtainer = copy)
        push!(model.container, 37.2)
        collect_model_data!(model_data, model, model_props, 1; obtainer = copy)
        model.container[1] += 21.9
        collect_model_data!(model_data, model, model_props, 2; obtainer = copy)
        @test model_data.container[1][1] ≈ 50.0
        @test model_data.container[3][1] ≈ 71.9
        @test length.(model_data.container) == [1, 2, 2]

        model = initialize()
        model_props = [:deep]
        model_data = init_model_dataframe(model, model_props)
        push!(model.deep.data, 17.5)
        collect_model_data!(model_data, model, model_props, 0; obtainer = deepcopy)
        push!(model.deep.data, 1.2)
        collect_model_data!(model_data, model, model_props, 1; obtainer = deepcopy)
        model.deep.data[1] += 0.9
        collect_model_data!(model_data, model, model_props, 2; obtainer = deepcopy)
        @test model_data[1, :deep].data[1] ≈ 20.0
        @test model_data[3, :deep].data[1] ≈ 20.9
        @test [length(d.data) for d in model_data[!, :deep]] == [3, 4, 4]

        model = initialize()
        agent_data, model_data = run!(
            model,
            agent_step!,
            model_step!,
            365 * 5;
            when_model = [1, 365 * 5],
            when = false,
            mdata = [:flag, :year, :container, :deep],
            adata = [(:weight, mean)],
            obtainer = deepcopy,
        )
        @test size(agent_data) == (0, 2)
        @test size(model_data) == (2, 5)
    end

    @testset "init_model_dataframe issue #494 fix" begin
        # Ensure that model_init_dataframe works when properties are specified as a struct.
        struct Props
            a::Float64
            b::Bool
        end

        model = ABM(
            Agent3,
            GridSpace((10, 10));
            properties=Props(1, false),
        )
        mdata = [:a, :b]

        model_data = init_model_dataframe(model, mdata)
        @test eltype.(eachcol(model_data)) == [Int, Float64, Bool]
    end
end

@testset "Parameter scan" begin
    @agent Automata GridAgent{2} begin end
    function forest_fire(; density = 0.7, griddims = (100, 100))
        space = GridSpace(griddims; periodic = false, metric = :euclidean)
        forest = ABM(Automata, space; properties = (trees = zeros(Int, griddims),))
        for I in CartesianIndices(forest.trees)
            if rand(forest.rng) < density
                forest.trees[I] = I[1] == 1 ? 2 : 1
            end
        end
        return forest
    end
    
    function forest_model_step!(forest)
        for I in findall(isequal(2), forest.trees)
            for idx in nearby_positions(I.I, forest)
                if forest.trees[idx...] == 1
                    forest.trees[idx...] = 2
                end
            end
            forest.trees[I] = 3
        end
    end

    n = 10
    parameters = Dict(:density => [0.6, 0.7, 0.8], :griddims => (20, 20))

    burnt(f) = count(t == 3 for t in f.trees)
    unburnt(f) = count(t == 1 for t in f.trees)
    @testset "Standard Scan" begin
        mdata = [unburnt, burnt]
        _, data = paramscan(
            parameters,
            forest_fire;
            n = n,
            model_step! = forest_model_step!,
            mdata,
        )
        # 3 is the number of combinations of changing params
        @test size(data) == ((n + 1) * 3, 4)
        _, data = paramscan(
            parameters,
            forest_fire;
            n = n,
            model_step! = forest_model_step!,
            include_constants = true,
            mdata,
        )
        # 3 is the number of combinations of changing params,
        # 5 is 3+2, where 2 is the number of constant parameters
        @test size(data) == ((n + 1) * 3, 5)

        mdata = [burnt]
        _, data = paramscan(
            parameters,
            forest_fire;
            n = n,
            model_step! = forest_model_step!,
            mdata,
        )
        @test unique(data.step) == 0:10
        @test unique(data.density) == [0.6, 0.7, 0.8]
    end
end

@testset "Issue #179 fix" begin
    # only ids sorted, not properties
    model = ABM(Agent2)
    for i in 1:5
        add_agent!(model, i * 0.2)
    end
    data, _ = run!(model, dummystep, 2; adata = [:weight])
    @test data[1, :id] == 1 && data[1, :weight] ≈ 0.2
    @test data[3, :id] == 3 && data[3, :weight] ≈ 0.6
    @test data[6, :id] == 1 && data[6, :weight] ≈ 0.2
end

@testset "ensemblerun! and different seeds" begin
    function fake_model(seed)
        abm = ABM(Agent4, GridSpace((4, 4)); rng = MersenneTwister(seed))
        fill_space!(abm, _ -> rand(abm.rng, 1:1000))
        abm
    end
    as!(agent, model) = (agent.p = rand(model.rng, 1:1000))
    seeds = [1234, 563, 211]
    adata = [(:p, sum)]
    adf, _ = ensemblerun!(fake_model, as!, dummystep, 2; adata, seeds)
    @test adf[!, :sum_p] == unique(adf[!, :sum_p])
    @test sort!(adf[:, :ensemble]) == [1, 1, 1, 2, 2, 2, 3, 3, 3]
end
