include("definitions.jl")

println("\n\nData collection benchmarks ---------------------")
mp = [:flag, :year]
ap =[:weight]
apagg = [(:weight, mean)]
model = init1()

println("agent data initialization")
@btime init_agent_dataframe($model, $ap)

println("agent data init with aggregation")
@btime init_agent_dataframe($model, $apagg)

println("model data initialization")
@btime init_model_dataframe($model, $mp)

step!(model, as1!, ms1!, 1000)

model = init1()

println("agent data collection")
@btime collect_agent_data!(
    adf, $model, $ap
    ) setup=(adf = init_agent_dataframe($model, $ap))

println("agent data aggregation")
@btime collect_agent_data!(
    adf, $model, $apagg
    ) setup=(adf = init_agent_dataframe($model, $apagg))

println("model data collection")
@btime collect_model_data!(
    mdf, $model, $mp
    ) setup = (mdf = init_model_dataframe($model, $mp))
