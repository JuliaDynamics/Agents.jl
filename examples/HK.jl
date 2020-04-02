# # HK (Hegselmann and Krause) opinion dynamics model

# This example showcases
# * How to do synchronous updating of Agent properties
#   (also know as [Synchronous update schedule](http://jmckalex.org/compass/syn-and-asynch-expl.html)).
#   In a Synchronous update schedule changes made to an agent are not seen by
#   other agents until the next step, see also [Wilensky 2015, p.286](https://mitpress.mit.edu/books/introduction-agent-based-modeling)).
# * How to terminate the system evolution on demand according to a boolean function.
# * How to terminate the system evolution according to what happened on the _previous_ step.

# ## Model overview

# This is an implementation of a simple version of the
# [Hegselmann and Krause (2002)](http://jasss.soc.surrey.ac.uk/5/3/2.html) model.
# It is a model of opinion formation with the question: which
# parameters' values lead to consensus, polarization or fragmentation?
# It models interacting **groups** of agents (as opposed to interacting pairs, typical in
# the literature) in which it is assumed that if an agent disagrees too much with
# the opinion of a source of influence, the source can no longer influence the
# agent’s opinion. There is then a "bound of confidence". The model shows that the
# systemic configuration is heavily dependent on this parameter's value.

# The model has the following components:

# - A set of n Agents with opinions xᵢ in the range [0,1] as attribute
# - A parameter ϵ called "bound" in (0, 0.3]
# - The update rule: at each step every agent adopts the mean of the opinions which are within
#   the confidence bound ( |xᵢ - xⱼ| ≤ ϵ).


# ## Core structures
# We start by defining the Agent type and initializing the model.
# The Agent type has two fields so that we can implement the synchronous update.
using Agents
using Statistics: mean

mutable struct HKAgent <: AbstractAgent
    id::Int
    old_opinion::Float64
    new_opinion::Float64
    previous_opinon::Float64
end

# There is a reason the agent has three fields that are "the same".
# The `old_opinion` is used for synchronous agent update, since we require access
# to a property's value at the start of the step and the end of the step.
# The `previous_opinion` is the opinion of the agent in the _previous_ step,
# since for the model termination we require access to a property's value
# at the end of the previous step, and the end of the current step.

# We could also make the three opinions a single field with vector value.

function hk_model(;numagents = 100, ϵ = 0.2)
    model = ABM(HKAgent, scheduler = fastest,
                properties = Dict(:ϵ => ϵ))
    for i in 1:numagents
        o = rand()
        add_agent!(model, o, o, -1)
    end
    return model
end

model = hk_model()

# And some helper functions for the update rule. As there is a filter in
# the rule we implement it outside the `agent_step!` method. Notice that the filter
# is applied to the `:old_opinion` field.
function boundfilter(agent, model)
    filter(
        j -> abs(agent.old_opinion - j) < model.ϵ,
        [a.old_opinion for a in allagents(model)]
     )
end

# Now we implement the `agent_step!`
function agent_step!(agent, model)
    agent.previous_opinon = agent.old_opinion
    agent.new_opinion = mean(boundfilter(agent,model))
end

# and `model_step!`
function model_step!(model)
    for a in allagents(model)
        a.old_opinion = a.new_opinion
    end
end

# From this implementation we see that to implement synchronous scheduling
# we define an Agent type with an `old` and `new` fields for attributes that
# are changed through synchronous updating. In `agent_step!` we use the `old` field
# and after updating all the agents `new` field we use the `model_step!`
# to update the model for the next iteration.

# ## Running the model
# The parameter of interest is the `:new_opinion` field so we assign
# it to variable `agent_properties` and pass it to the `step!` method
# to be collected in a DataFrame.

# In addition, we want to run the model
# only until all agents have converged to an opinion. From the documentation of
# [`step!`](@ref) one can see that instead of specifying the amount of steps we can specify
# a function instead.
function terminate(model, s)
    if any(!isapprox(a.previous_opinon, a.new_opinion; rtol = 1e-12)
            for a in allagents(model))
        return false
    else
        return true
    end
end

step!(model, agent_step!, model_step!, terminate)
model[1]

# Alright, let's wrap everything in a function and do some data collection using [`run!`](@ref).
# %% #src

function model_run(; kwargs...)

    model = hk_model(; kwargs...)

    agent_properties = [:new_opinion]
    agent_data, _ = run!(model,
        agent_step!,
        model_step!,
        terminate,
        agent_properties = agent_properties,
    )
    return agent_data
end

data = model_run(numagents = 100)
data[end-19:end, :]

# Finally we run three scenarios, collect the data and plot it.
# %% #src
using Plots, Random

plotsim(data, ϵ) = plot(
    data[!, :step],
    data[!, :new_opinion],
    leg= false,
    group = data[!, :id],
    title = "epsilon = $(ϵ)"
)

Random.seed!(42)

plt001,plt015,plt03 = map(
    e -> (model_run(ϵ= e), e) |>
    t -> plotsim(t[1], t[2]),
    [0.05, 0.15, 0.3]
)

plot(plt001, plt015, plt03, layout = (3,1))
