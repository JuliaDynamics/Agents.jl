using Agents, Test, DataFrames

@testset "DataCollection" begin
    @agent struct AgentWeight(GridAgent{2})
        weight::Float64 = 2.0
    end
    @agent struct AgentInteger(GridAgent{2})
        p::Int = 1
    end

    mutable struct Nested
        data::Vector{Float64}
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

    function initialize()
        model = StandardABM(
            AgentWeight,
            GridSpace((10, 10));
            agent_step! = agent_step!,
            model_step! = model_step!,
            properties = Dict(
                :year => 0,
                :tick => 0,
                :flag => false,
                :container => Float64[],
                :deep => Nested([20.0, 52.1])
            ),
        )
        add_agent!((4, 3), model, 0.1)
        add_agent!((7, 5), model, 0.35)
        add_agent!((2, 9), model, 0.67)
        return model
    end

    x_position(agent) = first(agent.pos)
    model = initialize()

    @testset "DataFrame init" begin
        @test init_agent_dataframe(model, nothing) == DataFrame()
        @test collect_agent_data!(DataFrame(), model, nothing) == DataFrame()

        @test init_model_dataframe(model, nothing) == DataFrame()
        @test collect_model_data!(DataFrame(), model, nothing) == DataFrame()

        props = [:weight]
        @test sprint(
            show,
            "text/csv",
            describe(init_agent_dataframe(model, props), :eltype),
        ) ==
              "\"variable\",\"eltype\"\n\"time\",\"Int64\"\n\"id\",\"Int64\"\n\"weight\",\"Float64\"\n"
        props = [:year]
        @test sprint(
            show,
            "text/csv",
            describe(init_model_dataframe(model, props), :eltype),
        ) == "\"variable\",\"eltype\"\n\"time\",\"Int64\"\n\"year\",\"Int64\"\n"

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
        collect_agent_data!(df, model, props)
        # Expecting weight values of all three agents. ID and time included.
        @test size(df) == (3, 3)
        @test propertynames(df) == [:time, :id, :weight]
        @test mean(df[!, :weight]) ≈ 0.37333333333

        props = [(:weight, mean)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        # Activate aggregation. Weight column is expected to be one value for this time point,
        # renamed mean(weight). ID is meaningless and will therefore be dropped.
        @test size(df) == (1, 2)
        @test propertynames(df) == [:time, :mean_weight]
        @test df[1, dataname((:weight, mean))] ≈ 0.37333333333

        # Add a function as a property
        props = [:weight, x_position]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (3, 4)
        @test propertynames(df) == [:time, :id, :weight, :x_position]
        @test mean(df[!, :x_position]) ≈ 4.3333333

        props = [(:weight, mean), (x_position, mean)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 3)
        @test propertynames(df) == [:time, :mean_weight, :mean_x_position]
        @test df[1, dataname(props[2])] ≈ 4.3333333

        xtest(agent) = agent.pos[1] > 5
        ytest(agent) = agent.pos[2] > 5

        props = [(:weight, mean, ytest)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 2)
        @test propertynames(df) == [:time, :mean_weight_ytest]
        @test df[1, dataname((:weight, mean, ytest))] ≈ 0.67

        props = [(:weight, mean), (:weight, mean, ytest)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 3)
        @test propertynames(df) == [:time, :mean_weight, :mean_weight_ytest]
        @test df[1, dataname(props[1])] ≈ 0.37333333333
        @test df[1, dataname(props[2])] ≈ 0.67

        props = [(:weight, mean, xtest), (:weight, mean, ytest)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 3)
        @test propertynames(df) == [:time, :mean_weight_xtest, :mean_weight_ytest]
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
            365 * 5;
            when_model = each_year,
            when = six_months,
            mdata = [:flag, :year],
            adata = [(:weight, mean)],
        )

        @test size(agent_data) == (11, 2)
        @test propertynames(agent_data) == [:time, :mean_weight]
        @test maximum(agent_data[!, :time]) == 1820

        @test size(model_data) == (6, 3)
        @test propertynames(model_data) == [:time, :flag, :year]
        @test maximum(model_data[!, :time]) == 1825

        agent_data, model_data = run!(
            model,
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
            365 * 5;
            when_model = [1, 365 * 5],
            when = false,
            mdata = [:deep],
            obtainer = deepcopy,
        )
        @test model_data[1, :deep].data[1] < model_data[end, :deep].data[1]

        _, model_data = run!(
            model,
            365 * 5;
            when_model = [365 * 5],
            when = false,
            mdata = [(m) -> (m.deep.data[i]) for i in 1:length(model.deep.data)],
        )
        @test Array{Float64,1}(model_data[1, 2:end]) == model.deep.data

        @testset "Writing to file while running" begin

            # CSV
            offline_run!(model, 365 * 5;
                when_model = each_year,
                when = six_months,
                mdata = [:flag, :year],
                adata = [(:weight, mean)],
                writing_interval = 3
            )

            adata_saved = CSV.read("adata.csv", DataFrame)
            @test size(adata_saved) == (11, 2)
            @test propertynames(adata_saved) == [:time, :mean_weight]

            mdata_saved = CSV.read("mdata.csv", DataFrame)
            @test size(mdata_saved) == (6, 3)
            @test propertynames(mdata_saved) == [:time, :flag, :year]

            rm("adata.csv")
            rm("mdata.csv")
            @test !isfile("adata.csv")
            @test !isfile("mdata.csv")

            # removing .arrow files after operating on them causes IO errors on Windows
            # so to make tests on Windows work we need to remove them when a new test
            # run occurs
            if Sys.iswindows()
                isfile("adata.arrow") && rm("adata.arrow")
                isfile("mdata.arrow") && rm("mdata.arrow")
            end

            offline_run!(model, 365 * 5;
                when_model = each_year,
                when = six_months,
                backend = :arrow,
                mdata = [:flag, :year],
                adata = [(:weight, mean)],
                writing_interval = 3
            )

            adata_saved = DataFrame(Arrow.Table("adata.arrow"))
            @test size(adata_saved) == (11, 2)
            @test propertynames(adata_saved) == [:time, :mean_weight]

            mdata_saved = DataFrame(Arrow.Table("mdata.arrow"))
            @test size(mdata_saved) == (6, 3)
            @test propertynames(mdata_saved) == [:time, :flag, :year]

            @test size(vcat(DataFrame.(Arrow.Stream("adata.arrow"))...)) == (11, 2)
            @test size(vcat(DataFrame.(Arrow.Stream("mdata.arrow"))...)) == (6, 3)

            if !(Sys.iswindows())
                rm("adata.arrow")
                rm("mdata.arrow")
                @test !isfile("adata.arrow")
                @test !isfile("mdata.arrow")
            end

            # Backends
            @test_throws TypeError begin
                offline_run!(model, 365 * 5; backend = "hdf5")
            end
            @test_throws AssertionError begin
                offline_run!(model, 365 * 5; backend = :hdf5)
            end
        end
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
                step!(model, 1)
                collect_model_data!(daily_model_data, model, model_props)
                collect_model_data!(daily_model_data_fn, model, model_props_fn)
                collect_agent_data!(daily_agent_aggregate, model, agent_agg)
            end
            collect_agent_data!(yearly_agent_data, model, agent_props)
        end

        @test size(daily_model_data) == (1825, 3)
        @test propertynames(daily_model_data) == [:time, :flag, :year]
        @test maximum(daily_model_data[!, :time]) == 1825

        @test size(daily_model_data_fn) == (1825, 3)
        @test propertynames(daily_model_data_fn) == [:time, :flagfn, :yearfn]
        @test maximum(daily_model_data_fn[!, :time]) == 1825

        @test size(daily_agent_aggregate) == (1825, 2)
        @test propertynames(daily_agent_aggregate) == [:time, :mean_weight]
        @test maximum(daily_agent_aggregate[!, :time]) == 1825

        @test size(yearly_agent_data) == (15, 3)
        @test propertynames(yearly_agent_data) == [:time, :id, :weight]
        @test maximum(yearly_agent_data[!, :time]) == 1825

        @test dummystep(model) === nothing
        @test dummystep(model[1], model) === nothing
        tick = model.tick
        step!(model, 1)
        @test tick + 1 == model.tick
        stop(m, s) = m.year == 6
        step!(model, stop)
        @test model.tick == 365 * 6
    end

    @testset "Mixed-ABM collections" begin
        model = StandardABM(Union{AgentWeight,AgentInteger}, GridSpace((10, 10)); warn = false, warn_deprecation = false)
        add_agent!((6, 8), AgentWeight, model, 54.65)
        add_agent!((10, 7), AgentInteger, model, 5)

        # Expect position type (both agents have it)
        props = [:pos]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (2, 4)
        @test propertynames(df) == [:time, :id, :agent_type, :pos]
        @test df[1, :pos] == model[1].pos
        @test df[2, :pos] == model[2].pos

        # Expect weight for AgentWeight, but missing for AgentInteger
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

        add_agent!((2, 4), AgentWeight, model, 19.81)
        add_agent!((4, 1), AgentInteger, model, 3)

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

        # Aggregates should behave in a similar fashion
        pos1(a) = a.pos[1]
        props = [(:pos, length), (pos1, sum)]
        df = init_agent_dataframe(model, props)
        collect_agent_data!(df, model, props)
        @test size(df) == (1, 3)
        @test typeof(df.length_pos) <: Vector{Int}
        @test df[1, :length_pos] == 4
        @test typeof(df.sum_pos1) <: Vector{Int}
        @test df[1, :sum_pos1] == 22

        # Expect aggregate to filter out AgentInteger's
        a3(a) = a isa AgentWeight
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

        # Handle mismatches
        # In this example, weight exists in both agents, but they have different types
        @agent struct Agent3Int(GridAgent{2})
            weight::Int
        end
        model = StandardABM(Union{AgentWeight,Agent3Int}, GridSpace((10, 10)); warn = false, warn_deprecation = false)
        add_agent!((6, 8), AgentWeight, model, 54.65)
        add_agent!((10, 7), Agent3Int, model, 5)
        add_agent!((2, 4), AgentWeight, model, 19.81)
        add_agent!((4, 1), Agent3Int, model, 3)

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

        # Handle dataframe initialization when one agent type is absent
        model = StandardABM(Union{AgentWeight,AgentInteger}, GridSpace((10, 10)); warn = false, warn_deprecation = false)
        add_agent!((6, 8), AgentWeight, model, 54.65)

        # get fieldtype from AgentInteger struct definition when agent is absent
        props = [:weight, :p]
        df = init_agent_dataframe(model, props)
        @test eltype(df[!, :p]) == Union{Int, Missing}

        # Add AgentInteger and check data collection
        add_agent!((4, 1), AgentInteger, model, 3)
        collect_agent_data!(df, model, props)
        @test size(df) == (2, 5)
        @test df[1, :weight] == model[1].weight
        @test df[2, :p] == model[2].p
        @test ismissing(df[1, :p])
        @test ismissing(df[2, :weight])
    end

    @testset "Observers" begin
        model = initialize()
        model_props = [:container]
        model_data = init_model_dataframe(model, model_props)
        push!(model.container, 50.0)
        collect_model_data!(model_data, model, model_props; obtainer = copy)
        push!(model.container, 37.2)
        collect_model_data!(model_data, model, model_props; obtainer = copy)
        model.container[1] += 21.9
        collect_model_data!(model_data, model, model_props; obtainer = copy)
        @test model_data.container[1][1] ≈ 50.0
        @test model_data.container[3][1] ≈ 71.9
        @test length.(model_data.container) == [1, 2, 2]

        model = initialize()
        model_props = [:deep]
        model_data = init_model_dataframe(model, model_props)
        push!(model.deep.data, 17.5)
        collect_model_data!(model_data, model, model_props; obtainer = deepcopy)
        push!(model.deep.data, 1.2)
        collect_model_data!(model_data, model, model_props; obtainer = deepcopy)
        model.deep.data[1] += 0.9
        collect_model_data!(model_data, model, model_props; obtainer = deepcopy)
        @test model_data[1, :deep].data[1] ≈ 20.0
        @test model_data[3, :deep].data[1] ≈ 20.9
        @test [length(d.data) for d in model_data[!, :deep]] == [3, 4, 4]

        model = initialize()
        agent_data, model_data = run!(
            model,
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

        model = StandardABM(
            AgentWeight,
            GridSpace((10, 10));
            properties=Props(1, false),
            warn_deprecation = false
        )
        mdata = [:a, :b]

        model_data = init_model_dataframe(model, mdata)
        @test eltype.(eachcol(model_data)) == [Int, Float64, Bool]
    end
end

@testset "Ensemble runs" begin

    nsteps = 100
    nreplicates = 2
    numagents_low = 280
    numagents_high = 300
    numagents(model) = nagents(model)

    expected_nensembles = nreplicates * (numagents_high - numagents_low + 1)
    function genmodels()
        basemodels = [AgentsExampleZoo.schelling(; numagents)
                      for numagents in numagents_low:numagents_high
                      for _ in 1:nreplicates]
        return basemodels
    end

    @testset begin "Serial ensemblerun!"

        models = genmodels()
        @assert length(models) == expected_nensembles

        adf, mdf, _ = ensemblerun!(models, nsteps;
                                   parallel = false, adata = [:pos, :mood, :group],
                                   mdata = [numagents, :min_to_be_happy])

        @test length(unique(adf.ensemble)) == expected_nensembles
        @test length(unique(adf.time)) == nsteps + 1
        @test length(unique(mdf.numagents)) == (numagents_high - numagents_low + 1)
    end

    @testset begin "Parallel ensemblerun!"

        models = genmodels()
        @assert length(models) == expected_nensembles

        adf, mdf, _ = ensemblerun!(models, nsteps;
                                   parallel = true,
                                   adata = [:pos, :mood, :group],
                                   mdata = [numagents, :min_to_be_happy],
                                   when = (model, step) -> step % 10 == 0 )

        @test length(unique(adf.ensemble)) == expected_nensembles
        @test length(unique(adf.time)) == (nsteps / 10) + 1
        @test length(unique(mdf.numagents)) == (numagents_high - numagents_low + 1)
    end

    @testset begin "Parallel ensemblerun! with stopping function"

        models = genmodels()
        @assert length(models) == expected_nensembles

        stopfn(model, step) = all(map(agent -> agent.mood, allagents(model)))

        adf, mdf, _ = ensemblerun!(models, stopfn;
                                   parallel = true,
                                   adata = [:pos, :mood, :group],
                                   mdata = [numagents, :min_to_be_happy],
                                   when = (model, step) -> step % 10 == 0 )

        @test length(unique(adf.ensemble)) == expected_nensembles
        @test length(unique(adf.time)) ≤ (nsteps / 10) + 1
        @test length(unique(mdf.numagents)) == (numagents_high - numagents_low + 1)
    end
end

@testset "Parameter scan" begin
    @everywhere @agent struct Automata(GridAgent{2})
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

    function forest_fire(; density = 0.7, griddims = (100, 100))
        space = GridSpace(griddims; periodic = false, metric = :euclidean)
        forest = StandardABM(Automata, space; model_step! = forest_model_step!,
                     properties = (trees = zeros(Int, griddims),), warn_deprecation = false)
        for I in CartesianIndices(forest.trees)
            if rand(abmrng(forest)) < density
                forest.trees[I] = I[1] == 1 ? 2 : 1
            end
        end
        return forest
    end

    n = 10
    parameters = Dict(:density => [0.6, 0.7, 0.8], :griddims => (20, 20))

    burnt(f) = count(t == 3 for t in f.trees)
    unburnt(f) = count(t == 1 for t in f.trees)
    terminate(m, s) = s >= 3 ? true : false
    @testset "Serial Scan" begin
        mdata = [unburnt, burnt]
        _, mdf = paramscan(
            parameters,
            forest_fire;
            n,
            mdata,
        )
        # 3 is the number of combinations of changing params
        @test size(mdf) == ((n + 1) * 3, 4)
        _, mdf = paramscan(
            parameters,
            forest_fire;
            n,
            include_constants = true,
            mdata,
        )
        # 3 is the number of combinations of changing params,
        # 5 is 3+2, where 2 is the number of constant parameters
        @test size(mdf) == ((n + 1) * 3, 5)
        mdata = [burnt]
        _, mdf = paramscan(
            parameters,
            forest_fire;
            n,
            mdata,
        )
        @test unique(mdf.time) == 0:10
        @test unique(mdf.density) == [0.6, 0.7, 0.8]

        # test whether paramscan accepts n::Function
        mdata = []
        _, mdf = paramscan(
            parameters,
            forest_fire;
            n = terminate,
            mdata)
        @test unique(mdf.time) == 0:3
    end

    @testset "Parallel Scan" begin
        mdata = [unburnt, burnt]
        _, mdf = paramscan(
            parameters,
            forest_fire;
            n,
            mdata,
        )
        # 3 is the number of combinations of changing params
        @test size(mdf) == ((n + 1) * 3, 4)
        _, mdf = paramscan(
            parameters,
            forest_fire;
            n,
            include_constants = true,
            mdata,
            parallel = true
        )
        # 3 is the number of combinations of changing params,
        # 5 is 3+2, where 2 is the number of constant parameters
        @test size(mdf) == ((n + 1) * 3, 5)
        mdata = [burnt]
        _, mdf = paramscan(
            parameters,
            forest_fire;
            n,
            mdata,
            parallel = true
        )
        @test unique(mdf.time) == 0:10
        @test unique(mdf.density) == [0.6, 0.7, 0.8]

        # test whether paramscan accepts n::Function
        mdata = []
        _, mdf = paramscan(
            parameters,
            forest_fire;
            n = terminate,
            mdata,
            parallel = true)
        @test unique(mdf.time) == 0:3
    end
end

@testset "Issue #179 fix" begin
    # only ids sorted, not properties
    model = StandardABM(Agent2, warn_deprecation = false)
    for i in 1:5
        add_agent!(model, i * 0.2)
    end
    data, _ = run!(model, 2; adata = [:weight])
    @test data[1, :id] == 1 && data[1, :weight] ≈ 0.2
    @test data[3, :id] == 3 && data[3, :weight] ≈ 0.6
    @test data[6, :id] == 1 && data[6, :weight] ≈ 0.2
end

@testset "ensemblerun! and different seeds" begin
    as!(agent, model) = (agent.p = rand(abmrng(model), 1:1000))
    function fake_model(seed)
        abm = StandardABM(AgentInteger, GridSpace((4, 4)); agent_step! = as!,
                  rng = MersenneTwister(seed), warn_deprecation = false)
        fill_space!(abm, _ -> rand(abmrng(abm), 1:1000))
        abm
    end
    seeds = [1234, 563, 211]
    adata = [(:p, sum)]
    adf, _ = ensemblerun!(fake_model, 2; adata, seeds)
    @test adf[!, :sum_p] == unique(adf[!, :sum_p])
    @test sort!(adf[:, :ensemble]) == [1, 1, 1, 2, 2, 2, 3, 3, 3]
end
