# # Optimizing agent-based models

# Sometimes we need to fine-tune our ABMs parameters to a specific outcome. The brute-force solution can quickly become infeasible for even for a few different parameter settings over a number of valid scan ranges. Most of the time, ABMs are also stochastic, so the effect of a parameter setting should be derived from taking the average value only after running the model several times.

# Here we show how to use the evolutionary algorithms in [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl) with Agents.jl, to optimize the parameters of an epidemiological model (SIR). We explain this model in detail in [SIR model for the spread of COVID-19](@ref). For brevity here, we just import

# ```julia
# include("siroptim.jl") # From the examples directory
# ```

# which provides us a `model_initiation` helper function to build a SIR model, and an `agent_step!` function.

# To look for optimal parameters, we need to define a cost function. The cost function takes as arguments the model parameters that we want to tune; in a SIR model, that would be the migration rate, death rate, transmission rate, when an infected person has been detected (`β_det`), or when the remain undetected (`β_und`), infection period, reinfection probability, and time until the infection is detected. The function returns an *objective*: this value takes the form one or more numbers, which the optimiser will attempt to minimize.

# ```julia
# using BlackBoxOptim, Random
# using Statistics: mean
#
# function cost(x)
#     model = model_initiation(;
#         Ns = [500, 500, 500],
#         migration_rate = x[1],
#         death_rate = x[2],
#         β_det = x[3],
#         β_und = x[4],
#         infection_period = x[5],
#         reinfection_probability = x[6],
#         detection_time = x[7],
#     )
# 
#     infected_fraction(model) =
#         count(a.status == :I for a in allagents(model)) / nagents(model)
# 
#     _, data = run!(
#         model,
#         agent_step!,
#         50;
#         mdata = [infected_fraction],
#         when_model = [50],
#         replicates = 10,
#     )
#
#     return mean(data.infected_fraction)
# end
# ```

# This cost function runs our model 10 times for 50 days, then returns the average number of infected people.
# When we pass this function to an optimiser, we will effectively be asking for a set of parameters that can reduce the number of infected people to the lowest possible number.

# We can now test the function cost with some reasonable parameter values.
# ```julia
# Random.seed!(10)
#
# x0 = [
#     0.2,  # migration_rate
#     0.1,  # death_rate
#     0.05, # β_det
#     0.3,  # β_und
#     10,   # infection_period
#     0.1,  # reinfection_probability
#     5,    # detection_time
# ]
# cost(x0)
# ```
# ```@raw html
# <pre class="documenter-example-output">0.9059485530546623</pre>
# ```

# With these initial values, 94% of the population is infected after the 50 day period.

# We now let the optimization algorithm change parameters to minimize the number of infected individuals. Complete details on how to use this optimiser can be found in the [BlackBoxOptim readme](https://github.com/robertfeldt/BlackBoxOptim.jl). Here, we assign a range of possible parameter values we would like to test, and a cutoff time in the event that certain parameter sets are unfeasible and cause our model to never converge to a solution.

# ```julia
# result = bboptimize(
#     cost,
#     SearchRange = [
#         (0.0, 1.0),
#         (0.0, 1.0),
#         (0.0, 1.0),
#         (0.0, 1.0),
#         (7.0, 13.0),
#         (0.0, 1.0),
#         (2.0, 6.0),
#     ],
#     NumDimensions = 7,
#     MaxTime = 20,
# )
# best_fitness(result)
# ```
# ```@raw html
# <pre class="documenter-example-output">0.0</pre>
# ```

# With the new parameter values found in `result`, we find that the fraction of the infected population can be dropped down to 11%.
# These values of these parameters are now:
# ```julia
# best_candidate(result)
# ```
# ```@raw html
# <pre class="documenter-example-output">7-element Array{Float64,1}:
#  0.1545049978104396
#  0.886202142470518
#  0.8258299702140992
#  0.7411762981538305
#  9.172098752376595
#  0.17302035312870545
#  5.907046385323653
# </pre>
# ```

# Unfortunately we've not given the optimiser information we probably needed to. Notice that the death rate is 96%, with reinfection quite low.
# When all the infected individuals die, infection doesn't transmit - the optimiser has managed to reduce the infection rate by killing the infected.

# This is not the work of some sadistic AI, just an oversight in our instructions.
# Let's modify the cost function to also keep the mortality rate low.

# First, we'll run the model with our new-found parameters:
# ```julia
# x = best_candidate(result)
#
# Random.seed!(0)
#
# model = model_initiation(;
#     Ns = [500, 500, 500],
#     migration_rate = x[1],
#     death_rate = x[2],
#     β_det = x[3],
#     β_und = x[4],
#     infection_period = x[5],
#     reinfection_probability = x[6],
#     detection_time = x[7],
# )
#
# _, data =
#     run!(model, agent_step!, 50; mdata = [nagents], when_model = [50], replicates = 10)
#
# mean(data.nagents)
# ```
# ```@raw html
# <pre class="documenter-example-output">2.0</pre>
# ```

# About 10% of the population dies with these parameters over our 50 day window.

# We can define a multi-objective cost function that minimizes the number of infected and deaths by returning more than one value in our cost function.
# ```julia
# function cost_multi(x)
#     model = model_initiation(;
#         Ns = [500, 500, 500],
#         migration_rate = x[1],
#         death_rate = x[2],
#         β_det = x[3],
#         β_und = x[4],
#         infection_period = x[5],
#         reinfection_probability = x[6],
#         detection_time = x[7],
#     )
#
#     initial_size = nagents(model)
#
#     infected_fraction(model) =
#         count(a.status == :I for a in allagents(model)) / nagents(model)
#     n_fraction(model) = -1.0 * nagents(model) / initial_size
#
#     mdata = [infected_fraction, n_fraction]
#     _, data = run!(
#         model,
#         agent_step!,
#         50;
#         mdata,
#         when_model = [50],
#         replicates = 10,
#     )
#
#     return mean(data[!, dataname(mdata[1])), mean(data[!, dataname(mdata[2]))
# end
# ```

# Notice that our new objective `n_fraction` is negative. It would be simpler to state we'd like to 'maximise the living population', but the optimiser we're using here focuses on minimising objectives only, therefore we must 'minimise the number of agents dying'.

# ```julia
# cost_multi(x0)
# ```
# ```@raw html
# <pre class="documenter-example-output">(0.9812286689419796, -0.7813333333333333)</pre>
# ```

# The cost of our initial parameter values is high: most of the population (96%) is infected and 22% die.

# Let's minimize this multi-objective cost function. There is more than one way to approach such an optimisation. Again, refer to the [BlackBoxOptim readme](https://github.com/robertfeldt/BlackBoxOptim.jl) for specifics.
# ```julia
# result = bboptimize(
#     cost_multi,
#     Method = :borg_moea,
#     FitnessScheme = ParetoFitnessScheme{2}(is_minimizing = true),
#     SearchRange = [
#         (0.0, 1.0),
#         (0.0, 1.0),
#         (0.0, 1.0),
#         (0.0, 1.0),
#         (7.0, 13.0),
#         (0.0, 1.0),
#         (2.0, 6.0),
#     ],
#     NumDimensions = 7,
#     MaxTime = 55,
# )
# best_fitness(result)
# ```
# ```@raw html
# <pre class="documenter-example-output">(0.0047011417058428475, -0.9926666666666668)</pre>
# ```

# ```julia
# best_candidate(result)
# ```
# ```@raw html
# <pre class="documenter-example-output">7-element Array{Float64,1}:
#   0.8798741355149663
#   0.6703698358420607
#   0.07093587652308599
#   0.07760264834010584
#  10.65213641721431
#   0.9911248984077646
#   5.869646301829334
# </pre>
# ```

# These parameters look better: about 0.3% of the population dies and 0.02% are infected:

# The algorithm managed to minimize the number of infected and deaths while still increasing death rate to 42%, reinfection probability to 53%, and migration rates to 33%.
# The most important change however, was decreasing the transmission rate when individuals are infected and undetected from 30% in our initial calculation, to 0.2%.

# Over a longer period of time than 50 days, that high death rate will take its toll though. Let's reduce that rate and check the cost.

# ```julia
# x = best_candidate(result)
# x[2] = 0.02
# cost_multi(x)
# ```
# ```@raw html
# <pre class="documenter-example-output">(0.03933333333333333, -1.0)</pre>
# ```

# The fraction of infected increases to 0.04%. This is an interesting result: since this virus model is not as deadly, the chances of re-infection increase.
# We now have a set of parameters to strive towards in the real world. Insights such as these assist us to enact countermeasures like social distancing to mitigate infection risks.

