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
    plot_locs(g, dims::Tuple{Integer, Integer, Integer})

Return three arrays for x, y, z coordinates of each node
"""
function node_locs(g, dims::Tuple{Integer, Integer, Integer})
  coords = []
  for nn in 1:nv(g)
    push!(coords, vertex_to_coord(nn, dims))
  end
  locs_x = [Float64(i[1]) for i in coords]
  locs_y = [Float64(i[2]) for i in coords]
  locs_z = [Float64(i[3]) for i in coords]
  return locs_x, locs_y, locs_z
end

"""
    visualize_2D_agent_distribution(data::DataFrame, model::AbstractModel, position_colomn::Symbol; types::Symbol=:id)

Show the distribution of agents on a 2D grid. You should provide `position_colomn` which is the name of the column that holds agent positions. If agents have different types and you want each type to be a different color, provide types=<column name>. Use a dictionary with `cc` to pass colors for each type. Available colors are "red", "green", "blue", "cyan", "pink", "yellow", "green2", and "black".
"""
function visualize_2D_agent_distribution(data::DataFrame, model::AbstractModel, position_column::Symbol; types::Symbol=:id, savename::AbstractString="2D_agent_distribution", cc::Dict=Dict())
  g = model.space.space
  locs_x, locs_y, locs_z = node_locs(g, model.space.dimensions)
  
  # base node color is light grey
  nodefillc = [RGBA(0.1,0.1,0.1,.1) for i in 1:gridsize(model.space.dimensions)]

  # change node color given the position of the agents. Automatically uses any columns with names: pos, or pos_{some number}
  # TODO a new plot where the alpha value of a node corresponds to the value of an individual on a node
  if types == :id  # there is only one type
    pos = position_column
    d = by(data, pos, N = pos => length)
    maxval = maximum(d[:N])
    nodefillc[d[pos]] .= [RGBA(0.1, 0.1, 0.1, i) for i in  (d[:N] ./ maxval) .- 0.001]
  else  # there are different types of agents based on the values of the "types" column
    dd = dropmissing(data[[position_column, types]])
    unique_types = sort(unique(dd[types]))
    pos = position_column
    colors = Dict("red"=>(0.9,0.1,0.1), "green"=>(0.1, 0.9, 0.1), "blue"=> (0.1,0.1,0.9), "cyan" => (0.5, 0.99, 0.99), "pink" => (0.99, 0.5, 0.99), "yellow" => (0.2, 0.9, 0.9), "green2"=>(0.01, 70, 0.4), "black" => (0.01,0.01,0.01))
    if length(cc) == 0
      colordict = Dict{Any, Tuple}()
      for ut in 1:length(unique_types)
        colordict[unique_types[ut]] = collect(values(colors))[ut]
      end
    else
      colordict = Dict{Any, Tuple}()
      for key in keys(cc)
        colordict[key] = colors[cc[key]]
      end
    end
    for index in 1:length(unique_types)
      tt = unique_types[index]
      d = by(dd[dd[types] .== tt, :], pos, N = pos => length)
      maxval = maximum(d[:N])
      # colormapname = "L$(index+1)"  # a linear colormap
      # (cmapc, name, desc) = cmap(colormapname, returnname=true)
      # nodefillc[d[pos]] .= [cmapc[round(Int64, i*256)] for i in  (d[:N] ./ maxval) .- 0.001]
      # println("$tt: $name")
      nodefillc[d[pos]] .= [RGBA(colordict[tt][1], colordict[tt][2], colordict[tt][3], i) for i in  (d[:N] ./ maxval) .- 0.001]
      println("$tt: $(colordict[tt])")
    end
  end

  draw(PDF("$savename.pdf"), gplot(g, locs_x, locs_y, nodefillc=nodefillc))
end