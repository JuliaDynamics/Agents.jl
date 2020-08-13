# # Optimizing agent-based models

# Agent-based models (ABMs) are computationally more expensive than analytical models, and can have many parameters. Sometimes we need to fine-tune a model's parameters to a specific outcome. Brute-force algorithms can take too long for testing each parameter setting. Even if it was feasbile to run the model for every parameter setting, it would not be enough because ABMs are stochastic and the effect of a parameter setting should be derived from running the model several times and taking its average behavior.

# Here we show how to use the evolutionary algorithms in [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl) with Agents.jl, to optimize the parameters of an epidemiological model (SIR). We explain this model in detail in [SIR model for the spread of COVID-19](@ref). For brevity here, we just import it.

cd(@__DIR__) #src
cd("../../../examples/") #src
include("siroptim.jl") ## From the examples directory

# Now we need to define a cost function. The cost function takes as agruments the model parameters that we want to tune, here migration rate, death rate, transmission rate when an infected person has been (not) detected (`β_det`, `β_und`), infection period, reinfection probability, and time until the infection is detected. The function returns one or more numbers as the objective to be minimized. Here, we try to minimize the number of infected people after 50 days.

using BlackBoxOptim
import Statistics: mean

function cost(x)
    migration_rate,
    death_rate,
    β_det,
    β_und,
    infection_period,
    reinfection_probability,
    detection_time = x
    C = 3
    params = create_params(
        C = C,
        Ns = [500 for i in 1:C],
        β_det = [β_det for i in 1:C],
        migration_rate = migration_rate,
        infection_period = infection_period,
        reinfection_probability = reinfection_probability,
        detection_time = detection_time,
        death_rate = death_rate,
        Is = ones(Int, C),
        β_und = [β_und for i in 1:C],
    )

    model = model_initiation(; params...)

    infected_fraction(model) =
        count(a.status == :I for a in values(model.agents)) / nagents(model)
    _, data = run!(
        model,
        agent_step!,
        50;
        mdata = [infected_fraction],
        when_model = [50],
        replicates = 10,
    )

    return mean(data.infected_fraction)
end

# Because ABMs are stochastic, we run 10 replicates and take the average fraction of infected people after 50 days

# We can now test the function cost with some reasonable parameter values.

Random.seed!(10)

migration_rate = 0.2
death_rate = 0.1
β_det = 0.05
β_und = 0.3
infection_period = 10
reinfection_probability = 0.1
detection_time = 5
x0 = [
    migration_rate,
    death_rate,
    β_det,
    β_und,
    infection_period,
    reinfection_probability,
    detection_time,
]
cost(x0)

# After 50 days, 94% of the population is infected.

# We let the optimization algorithm change parameters to minimize the number of infected individuals. Note that we can limit the allowed range for each parameter separately.

result = bboptimize(
    cost,
    SearchRange = [
        (0.0, 1.0),
        (0.0, 1.0),
        (0.0, 1.0),
        (0.0, 1.0),
        (7.0, 13.0),
        (0.0, 1.0),
        (2.0, 6.0),
    ],
    NumDimensions = 7,
    MaxTime = 20,
)
best_fitness(result)

# The fraction of the infected is down to 11%. Parameter values that give this result are:

best_candidate(result)

# We notice that the death rate is 96%, and transmission rates have also increased, while reinfection probability is much smaller. When all the infected indiduals die, infection doesn't transmit. Let's modify the cost function to also keep the mortality rate low.

# This can be tested by running the model with the new parameter values:
migration_rate,
death_rate,
β_det,
β_und,
infection_period,
reinfection_probability,
detection_time = best_candidate(result)
C = 3
params = create_params(
    C = C,
    Ns = [500 for i in 1:C],
    β_det = [β_det for i in 1:C],
    migration_rate = migration_rate,
    infection_period = infection_period,
    reinfection_probability = reinfection_probability,
    detection_time = detection_time,
    death_rate = death_rate,
    Is = ones(Int, C),
    β_und = [β_und for i in 1:C],
)

Random.seed!(0)
model = model_initiation(; params...)
nagents(model)

_, data =
    run!(model, agent_step!, 50; mdata = [nagents], when_model = [50], replicates = 10)

mean(data.nagents)

# About 10% of the population dies with these parameters.

# We can define a multi-objective cost function that minimizes the number of infected and deaths.

function cost_multi(x)
    migration_rate,
    death_rate,
    β_det,
    β_und,
    infection_period,
    reinfection_probability,
    detection_time = x
    C = 3
    params = create_params(
        C = C,
        Ns = [500 for i in 1:C],
        β_det = [β_det for i in 1:C],
        migration_rate = migration_rate,
        infection_period = infection_period,
        reinfection_probability = reinfection_probability,
        detection_time = detection_time,
        death_rate = death_rate,
        Is = ones(Int, C),
        β_und = [β_und for i in 1:C],
    )

    model = model_initiation(; params...)
    initial_size = nagents(model)

    infected_fraction(model) =
        count(a.status == :I for a in values(model.agents)) / nagents(model)
    n_fraction(model) = -1.0 * nagents(model) / initial_size
    _, data = run!(
        model,
        agent_step!,
        50;
        mdata = [infected_fraction, n_fraction],
        when_model = [50],
        replicates = 10,
    )

    return mean(data.infected_fraction), mean(data.n_fraction)
end

# The cost of our initial parameter values is high: most of the population (96%) is infected and 22% die.

cost_multi(x0)

# Let's minimize this multi-objective cost function. We need to define the optimization method for multi-objective functions:

result = bboptimize(
    cost_multi,
    Method = :borg_moea,
    FitnessScheme = ParetoFitnessScheme{2}(is_minimizing = true),
    SearchRange = [
        (0.0, 1.0),
        (0.0, 1.0),
        (0.0, 1.0),
        (0.0, 1.0),
        (7.0, 13.0),
        (0.0, 1.0),
        (2.0, 6.0),
    ],
    NumDimensions = 7,
    MaxTime = 55,
)

# With the optimized parameters, about 0.3% of the population dies and 0.02% are infected:

best_fitness(result)

# And the tuned parameters are

best_candidate(result)

# The algorithm managed to minimize the the number of infected and deaths while still increasing death rate to 42%, reinfection probability to 53%, and migration rates to 33%. The most important change decreasing the transmission rate when individuals are infected and undetected (from 30% to 0.2%).

# Let's reduce death rate and check the cost:

x = best_candidate(result)
x[2] = 0.02
cost_multi(x)

# The fraction of infected increases to 0.04%. This is an interesting result, confirming the importance of social distancing. Without changing infection period and travel rate, even by increasing the transmission rate of the infected and detected (from 5% to 20%), by just decreasing the transmission rate of the undetected individuals, death rate drops 73 times and the number of infected decreases from 96% of the population to 3%.

