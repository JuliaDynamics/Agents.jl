using BenchmarkTools, Agents

const SCHED_SUITE = BenchmarkGroup(["Schedulers"])

mutable struct FakeAgent <: AbstractAgent
    id::Int
    group::Int
end

mutable struct OtherFakeAgent <: AbstractAgent
    id::Int
end

function fake_model(; nagents = 500, scheduler)
    model = ABM(FakeAgent; scheduler)
    for i in 1:nagents
        add_agent!(model, i % 2)
    end
    model
end

function fake_model_multi(; nagents = 500, scheduler)
    model = ABM(Union{FakeAgent, OtherFakeAgent}; scheduler, warn = false)
    for i in 1:nagents
        if i % 2 == 0
            add_agent!(FakeAgent(i, 1), model)
        else
            add_agent!(OtherFakeAgent(i), model)
        end
    end
    model
end

for (model, name) in [
    (fake_model(; scheduler = Schedulers.fastest), "fastest"),
    (fake_model(; scheduler = Schedulers.by_id), "by_id"),
    (fake_model(; scheduler = Schedulers.ByID()), "ByID"),
    (fake_model(; scheduler = Schedulers.randomly), "randomly"),
    (fake_model(; scheduler = Schedulers.Randomly()), "Randomly"),
    (fake_model(; scheduler = Schedulers.by_property(:group)), "by_property"),
    (fake_model(; scheduler = Schedulers.ByProperty(:group)), "ByProperty"),
    (fake_model(; scheduler = Schedulers.partially(0.7)), "partially"),
    (fake_model(; scheduler = Schedulers.Partially(0.7)), "Partially"),
    (fake_model_multi(; scheduler = Schedulers.by_type(true, true)), "by_type"),
    (fake_model_multi(;
                      scheduler = Schedulers.ByType(true, true,
                                                    Union{FakeAgent, OtherFakeAgent})),
     "ByType"),
]
    SUITE[name] = @benchmarkable Agents.schedule($model)
end

SUITE["large_model"] = BenchmarkGroup(["by_id", "ByID", "randomly", "Randomly"])

for (model, name) in [
    (fake_model(; nagents = 800000, scheduler = Schedulers.fastest), "fastest"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.by_id), "by_id"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.ByID()), "ByID"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.randomly), "randomly"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.Randomly()), "Randomly"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.by_property(:group)),
     "by_property"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.ByProperty(:group)),
     "ByProperty"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.partially(0.7)), "partially"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.Partially(0.7)), "Partially"),
    (fake_model_multi(; nagents = 800000, scheduler = Schedulers.by_type(true, true)),
     "by_type"),
    (fake_model_multi(; nagents = 800000,
                      scheduler = Schedulers.ByType(true, true,
                                                    Union{FakeAgent, OtherFakeAgent})),
     "ByType"),
]
    SUITE["large_model"][name] = @benchmarkable Agents.schedule($model)
end

SUITE["small_model"] = BenchmarkGroup(["by_id", "ByID", "randomly", "Randomly"])

for (model, name) in [
    (fake_model(; nagents = 50, scheduler = Schedulers.fastest), "fastest"),
    (fake_model(; nagents = 50, scheduler = Schedulers.by_id), "by_id"),
    (fake_model(; nagents = 50, scheduler = Schedulers.ByID()), "ByID"),
    (fake_model(; nagents = 50, scheduler = Schedulers.randomly), "randomly"),
    (fake_model(; nagents = 50, scheduler = Schedulers.Randomly()), "Randomly"),
    (fake_model(; nagents = 50, scheduler = Schedulers.by_property(:group)), "by_property"),
    (fake_model(; nagents = 50, scheduler = Schedulers.ByProperty(:group)), "ByProperty"),
    (fake_model(; nagents = 50, scheduler = Schedulers.partially(0.7)), "partially"),
    (fake_model(; nagents = 50, scheduler = Schedulers.Partially(0.7)), "Partially"),
    (fake_model_multi(; nagents = 50, scheduler = Schedulers.by_type(true, true)),
     "by_type"),
    (fake_model_multi(; nagents = 50,
                      scheduler = Schedulers.ByType(true, true,
                                                    Union{FakeAgent, OtherFakeAgent})),
     "ByType"),
]
    SUITE["small_model"][name] = @benchmarkable Agents.schedule($model)
end
