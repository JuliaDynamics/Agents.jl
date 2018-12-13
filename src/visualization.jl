"""
    agents_plots_complete(property_plot::Array{Tuple}, model::AbstractModel)

Plots the agents_data_complete() results in your browser.

# Parameters

* property_plot: An array of tuples. The first element of the tuple is the agent property you would like to plot (as a symbol). The second element of the tuple is the type of plot you want on that property (as a symbol). Example: [(:wealth, :hist)]. Available plot types: :hist.

You can add more plot types by adding more if statements in the function.

Not working: VegaLite does not show the plot.
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

"""
    visualize_2D_agent_distribution(model::AbstractModel)

Creates a heatmap that shows the density of agents on each node of the 2D grid.
"""
function visualize_2D_agent_distribution(model::AbstractModel)
  x = [j for i in 1:model.space.dimensions[1], j in 1:model.space.dimensions[1]]
  y = [i for i in 1:model.space.dimensions[2], j in 1:model.space.dimensions[2]]
  # create an empty color for all the nodes
  z = [0 for i in 1:model.space.dimensions[1], j in 1:model.space.dimensions[1]]
  # Add color to each node:
  for node in 1:length(model.space.agent_positions)
    z[node] = length(model.space.agent_positions[node])
  end

  data = DataFrame(x=vec(x'),y=vec(y'),z=vec(z'))

  data |> @vlplot(:rect, x="x:o", y="y:o", color=:z)

end