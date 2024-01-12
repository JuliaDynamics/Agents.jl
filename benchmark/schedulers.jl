using BenchmarkTools, Agents

const SUITE = BenchmarkGroup(["Schedulers"])

@agent struct FakeAgent(NoSpaceAgent)
    group::Int
    incr::Int
end

@agent struct OtherFakeAgent(NoSpaceAgent)
    group::Int
    incr::Int
end

function fake_model(; nagents, scheduler)
    model = StandardABM(FakeAgent; scheduler)
    for i in 1:nagents
        add_agent!(model, i % 2, 0)
    end
    model
end

function fake_model_multi(; nagents, scheduler)
    model = StandardABM(Union{FakeAgent,OtherFakeAgent}; scheduler, warn = false)
    for i in 1:nagents
        if i % 2 == 0
            add_agent!(FakeAgent, model, 0, 0)
        else
            add_agent!(OtherFakeAgent, model, 1, 0)
        end
    end
    model
end

agent_step(agent, model) = agent.incr += 1

SUITE["large_model"] = BenchmarkGroup()

for (model, name) in [
    (fake_model(; nagents = 800000, scheduler = Schedulers.fastest), "fastest"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.by_id), "by_id"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.ByID()), "ByID"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.randomly), "randomly"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.Randomly()), "Randomly"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.by_property(:group)), "by_property"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.ByProperty(:group)), "ByProperty"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.partially(0.7)), "partially"),
    (fake_model(; nagents = 800000, scheduler = Schedulers.Partially(0.7)), "Partially"),
    (fake_model_multi(; nagents = 800000, scheduler = Schedulers.by_type(true, true)), "by_type"),
    (fake_model_multi(; nagents = 800000, scheduler = Schedulers.ByType(true, true, Union{FakeAgent,OtherFakeAgent})), "ByType")
]
    SUITE["large_model"][name] = @benchmarkable step!($model, agent_step, dummystep)
end

SUITE["medium_model"] = BenchmarkGroup()

for (model, name) in [
    (fake_model(; nagents = 2000, scheduler = Schedulers.fastest), "fastest"),
    (fake_model(; nagents = 2000, scheduler = Schedulers.by_id), "by_id"),
    (fake_model(; nagents = 2000, scheduler = Schedulers.ByID()), "ByID"),
    (fake_model(; nagents = 2000, scheduler = Schedulers.randomly), "randomly"),
    (fake_model(; nagents = 2000, scheduler = Schedulers.Randomly()), "Randomly"),
    (fake_model(; nagents = 2000, scheduler = Schedulers.by_property(:group)), "by_property"),
    (fake_model(; nagents = 2000, scheduler = Schedulers.ByProperty(:group)), "ByProperty"),
    (fake_model(; nagents = 2000, scheduler = Schedulers.partially(0.7)), "partially"),
    (fake_model(; nagents = 2000, scheduler = Schedulers.Partially(0.7)), "Partially"),
    (fake_model_multi(; nagents = 2000, scheduler = Schedulers.by_type(true, true)), "by_type"),
    (fake_model_multi(; nagents = 2000, scheduler = Schedulers.ByType(true, true, Union{FakeAgent,OtherFakeAgent})), "ByType")
]
    SUITE["medium_model"][name] = @benchmarkable step!($model, agent_step, dummystep)
end

SUITE["small_model"] = BenchmarkGroup()

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
    (fake_model_multi(; nagents = 50, scheduler = Schedulers.by_type(true, true)), "by_type"),
    (fake_model_multi(; nagents = 50, scheduler = Schedulers.ByType(true, true, Union{FakeAgent,OtherFakeAgent})), "ByType")
]
    SUITE["small_model"][name] = @benchmarkable step!($model, agent_step, dummystep)
end

results = run(SUITE, verbose = true, seconds = 5)
