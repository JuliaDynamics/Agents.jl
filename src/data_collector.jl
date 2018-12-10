# collect data with these specifications: https://mesa.readthedocs.io/en/master/tutorials/intro_tutorial.html#collecting-data

"""
    agents_data_per_step(properties::Array{Symbol}, aggregators::Array{Function})

Collect data from a `property` of agents (a `fieldname`) and apply `aggregators` function to them.

If a fieldname of agents returns an array, this will use the `mean` of the array on which to apply aggregators.

TODO
"""
function agents_data_per_step(properties::Array{Symbol}, aggregators::Array{Function}, model::AbstractModel)
  output = Array{Real}(undef, length(properties) * length(aggregators))
  agentslen = nagents(model)
  counter = 1
  for fn in properties
    if typeof(getproperty(model.agents[1], fn)) <: AbstractArray
      temparray = [mean(getproperty(model.agents[i], fn)) for i in 1:agentslen]
    else
      temparray = [getproperty(model.agents[i], fn) for i in 1:agentslen]
    end
    for agg in aggregators
      output[counter] = agg(temparray)
      counter += 1
    end
  end
  return output
end

"""
    agents_data_complete(properties::Array{Symbol}, model::AbstractModel)

Collect data from a `property` of agents (a `fieldname`) into a dataframe.

If a fieldname of agents returns an array, this will use the `mean` of the array
"""
function agents_data_complete(properties::Array{Symbol}, model::AbstractModel)
  # colnames = [join([string(i[1]), split(string(i[2]), ".")[end]], "_") for i in product(properties, aggregators)]
  dd = DataFrame()
  agentslen = nagents(model)
  for fn in properties
    if typeof(getproperty(model.agents[1], fn)) <: AbstractArray
      temparray = [mean(getproperty(model.agents[i], fn)) for i in 1:agentslen]
    else
      temparray = [getproperty(model.agents[i], fn) for i in 1:agentslen]
    end
    dd[fn] = temparray
  end
  return dd
end

"""
    agents_plots_complete(property_plot::Array{Tuple}, model::AbstractModel)

Plots the agents_data_complete() results in your browser.

# Parameters

* property_plot: An array of tuples. The first element of the tuple is the agent property you would like to plot (as a symbol). The second element of the tuple is the type of plot you want on that property (as a symbol). Example: [(:wealth, :hist)]. Available plot types: :hist.

You can add more plot types by adding more if statements in the function.
"""
function agents_plots_complete(property_plot::Array{Tuple{Symbol}}, model::AbstractModel)
  properties = [i[1] for i in property_plot]
  data = agents_data_complete(properties, model)
  for (property, pt) in property_plot
    if pt == :hist
      # data |> @vlplot(:bar, x={property, bin=true}, y="count()") # This is a bug and doesn't work
      data |> @vlplot(:bar, x=property, y="count()") # this is temporary until the above bug is fixed
      save("histogram.pdf")
    end
  end
end