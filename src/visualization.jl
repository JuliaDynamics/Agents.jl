"""
    agents_plots_complete(property_plot::Array{Tuple}, model::AbstractModel)

Plots the agents_data_complete() results in your browser.

# Parameters

* property_plot: An array of tuples. The first element of the tuple is the agent property you would like to plot (as a symbol). The second element of the tuple is the type of plot you want on that property (as a symbol). Example: [(:wealth, :hist)]. Available plot types: :hist.

You can add more plot types by adding more if statements in the function.

TODO: VegaLite does not show the plot.
"""
function agents_plots_complete(property_plot::Array, model::AbstractModel)
  properties = [i[1] for i in property_plot]
  data = agents_data_complete(properties, model)
  for (property, pt) in property_plot
    if pt == :hist
      # data |> @vlplot(:bar, x={property, bin=true}, y="count()") # This is a bug and doesn't work
      data |> @vlplot(:bar, x=property, y="count()") # this is temporary until the above bug is fixed
      # save("histogram.pdf")
    end
  end
end


function visualize_data(data::DataFrame)
  v = Voyager(data)
end

# TODO: visualize grids and networks