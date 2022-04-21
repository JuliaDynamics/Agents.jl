using BenchmarkTools, Agents

const SCHED_SUITE = BenchmarkGroup(["Schedulers"])

include("setup.jl")

for (scheduler, name) in [
        (Schedulers.fastest, "fastest"),
        (Schedulers.by_id, "by_id"),
        (Schedulers.ByID(), "ByID"),
        (Schedulers.randomly, "randomly"),
        (Schedulers.Randomly(), "Randomly"),
        (Schedulers.by_property(:group), "by_property"),
        (Schedulers.ByProperty(:group), "ByProperty"),
    ]
    model, agent_step!, model_step! = schelling_with_scheduler(; scheduler)
    SCHED_SUITE[name] = @benchmarkable step!($model, $agent_step!, $model_step!)
end

for (scheduler, name) in [
    (Schedulers.partially(0.7), "partially"),
    (Schedulers.Partially(0.7), "Partially")
]
    model, agent_step!, model_step! = flocking_with_scheduler(; scheduler)
    SCHED_SUITE[name] = @benchmarkable step!($model, $agent_step!, $model_step!)
end

for (scheduler, name) in [
    (Schedulers.by_type(true, true), "by_type"),
    (Schedulers.ByType(true, true, Union{SchellingAgentA,SchellingAgentB}), "ByType")
]
    model, agent_step!, model_step! = union_schelling_with_scheduler(; scheduler)
    SCHED_SUITE[name] = @benchmarkable step!($model, $agent_step!, $model_step!)
end

SCHED_SUITE["large_model"] = BenchmarkGroup(["by_id", "ByID", "randomly", "Randomly"])

for (scheduler, name) in [
    (Schedulers.by_id, "by_id"),
    (Schedulers.ByID(), "ByID"),
    (Schedulers.randomly, "randomly"),
    (Schedulers.Randomly(), "Randomly"),
]
    model, agent_step!, model_step! = schelling_with_scheduler(; numagents = 800000, griddims = (1000, 1000), scheduler)
    SCHED_SUITE["large_model"][name] = @benchmarkable step!($model, $agent_step!, $model_step!)
end

SCHED_SUITE["small_model"] = BenchmarkGroup(["by_id", "ByID", "randomly", "Randomly"])

for (scheduler, name) in [
    (Schedulers.by_id, "by_id"),
    (Schedulers.ByID(), "ByID"),
    (Schedulers.randomly, "randomly"),
    (Schedulers.Randomly(), "Randomly"),
]
    model, agent_step!, model_step! = schelling_with_scheduler(; numagents = 80, griddims = (10, 10), scheduler)
    SCHED_SUITE["small_model"][name] = @benchmarkable step!($model, $agent_step!, $model_step!)
end
