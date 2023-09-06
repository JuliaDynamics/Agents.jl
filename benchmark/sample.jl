using Agents, BenchmarkTools

@agent struct FakeAgent 
    fieldsof(NoSpaceAgent)
end

function fake_model(; nagents)
    model = StandardABM(FakeAgent)
    for i in 1:nagents
        add_agent!(model)
    end
    return model
end

@benchmark sample!(model, 10^5) setup=(model = fake_model(; nagents = 10^2)) evals=1
@benchmark sample!(model, 10^4) setup=(model = fake_model(; nagents = 10^2)) evals=1
@benchmark sample!(model, 10^3) setup=(model = fake_model(; nagents = 10^2)) evals=1
@benchmark sample!(model, 10^2) setup=(model = fake_model(; nagents = 10^2)) evals=1
@benchmark sample!(model, 10^1) setup=(model = fake_model(; nagents = 10^2)) evals=1
@benchmark sample!(model, 10^0) setup=(model = fake_model(; nagents = 10^2)) evals=1

@benchmark sample!(model, 10^5) setup=(model = fake_model(; nagents = 10^5)) evals=1
@benchmark sample!(model, 10^4) setup=(model = fake_model(; nagents = 10^5)) evals=1
@benchmark sample!(model, 10^3) setup=(model = fake_model(; nagents = 10^5)) evals=1
@benchmark sample!(model, 10^2) setup=(model = fake_model(; nagents = 10^5)) evals=1
@benchmark sample!(model, 10^1) setup=(model = fake_model(; nagents = 10^5)) evals=1
@benchmark sample!(model, 10^0) setup=(model = fake_model(; nagents = 10^5)) evals=1
