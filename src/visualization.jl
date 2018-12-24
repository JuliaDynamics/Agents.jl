"""
    agents_plots_complete(property_plot::Array{Tuple}, model::AbstractModel)

Plots the agents_data_complete() results in your browser.

# Parameters

* property_plot: An array of tuples. The first element of the tuple is the agent property you would like to plot (as a symbol). The second element of the tuple is the type of plot you want on that property (as a symbol). Example: [(:wealth, :hist)]. Available plot types: :hist.

You can add more plot types by adding more if statements in the function.
"""
function agents_plots_complete(property_plot::Array, model::AbstractModel)
  properties = [i[1] for i in property_plot]
  data = agents_data_complete(properties, model)
  for (property, pt) in property_plot
    if pt == :hist
      # data |> @vlplot(:bar, x={property, bin=true, title=property}, y={"count()", title="Frequency"}) # This is a bug and doesn't work
      data |> @vlplot(:bar, x=property, y="count()") |> save("histogram.pdf") # this is temporary until the above bug is fixed
    end
  end
end


function visualize_data(data::DataFrame)
  v = Voyager(data)
end

"""
    plot_locs(g, dims::Tuple{Integer,Integer,Integer})

Return three arrays for x, y, z coordinates of each node
"""
function node_locs(g, dims::Tuple{Integer,Integer,Integer})
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
    plot_locs(g, dims::Tuple{Integer,Integer})

Return arrays for x, y coordinates of each node
"""
function node_locs(g, dims::Tuple{Integer,Integer})
  coords = []
  for nn in 1:nv(g)
    push!(coords, vertex_to_coord(nn, dims))
  end
  locs_x = [Float64(i[1]) for i in coords]
  locs_y = [Float64(i[2]) for i in coords]
  return locs_x, locs_y
end

"""
    visualize_2D_agent_distribution(data::DataFrame, model::AbstractModel, position_colomn::Symbol; types::Symbol=:id)

Show the distribution of agents on a 2D grid. You should provide `position_colomn` which is the name of the column that holds agent positions. If agents have different types and you want each type to be a different color, provide types=<column name>. Use a dictionary with `cc` to pass colors for each type. You may choose any color name as is on the [list of colors on Wikipedia](https://en.wikipedia.org/wiki/Lists_of_colors).
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
    if length(cc) == 0
      colors = colorrgb(length(unique_types))
      colordict = Dict{Any, Tuple}()
      colorvalues = collect(values(colors))
      for ut in 1:length(unique_types)
        colordict[unique_types[ut]] = colorvalues[ut]
      end
    else
      colors = colorrgb(collect(values(cc)))
      colordict = Dict{Any, Tuple}()
      for key in keys(cc)
        colordict[key] = colors[cc[key]]
      end
    end
    colorrev = Dict(v=>k for (k,v) in colors)
    for index in 1:length(unique_types)
      tt = unique_types[index]
      d = by(dd[dd[types] .== tt, :], pos, N = pos => length)
      maxval = maximum(d[:N])
      # colormapname = "L$(index+1)"  # a linear colormap
      # (cmapc, name, desc) = cmap(colormapname, returnname=true)
      # nodefillc[d[pos]] .= [cmapc[round(Int64, i*256)] for i in  (d[:N] ./ maxval) .- 0.001]
      # println("$tt: $name")
      nodefillc[d[pos]] .= [RGBA(colordict[tt][1], colordict[tt][2], colordict[tt][3], i) for i in  (d[:N] ./ maxval) .- 0.001]
      println("$tt: $(colorrev[colordict[tt]])")
    end
  end

  NODESIZE = 1/sqrt(gridsize(model))
  draw(PDF("$savename.pdf"), gplot(g, locs_x, locs_y, nodefillc=nodefillc, edgestrokec=RGBA(0.1,0.1,0.1,.1), NODESIZE=NODESIZE))
end

"""
    colorrgb(color_names::Array)
Returns a dictionary of each colorname and its RGB values. See colors and names on [list of colors on Wikipedia](https://en.wikipedia.org/wiki/Lists_of_colors)
"""
function colorrgb(color_names::Array)
  script_path = splitdir(realpath(@__FILE__))[1]
  f = joinpath(script_path, "color_names.csv")
  ff = CSV.File(f)
  rgb_dict = Dict{AbstractString, Tuple}()
  for row in ff 
    if row.cname in color_names || row.cname2 in color_names
      rgb_dict[row.cname] = (row.R/256, row.G/256, row.B/256)
    end
  end
  if length(rgb_dict) < length(color_names)
    simm = intersect(keys(rgb_dict), color_names)
    for ss in keys(rgb_dict)
      if !in(ss, color_names)
        println("$ss is not a valid color name!")
      end
    end
    throw("Provide valid colornames.")
  end
  return rgb_dict
end

"""
    colornames(n::Integer)

Returns n random colors as a dictionary (Dict{colorname=>rgb})
"""
function colorrgb(n::Integer)
  script_path = splitdir(realpath(@__FILE__))[1]
  f = joinpath(script_path, "color_names.csv")
  ff = CSV.File(f)
  randcolors = rand(1:length(ff), n)
  rgb_dict = Dict{AbstractString, Tuple}()
  for (index,row) in enumerate(ff) 
    if index in randcolors
      rgb_dict[row.cname] = (row.R/256, row.G/256, row.B/256)
    end
  end
  return rgb_dict
end


"""
    visualize_1DCA(data::DataFrame, model::AbstractModel, position_column::Symbol, status_column::Symbol, nrows::Integer; savename::AbstractString="2D_agent_distribution")

Visualize data of a 1D cellular automaton. `data` are the result of multiple runs of the simulation. `position_column` is the field of the agent that holds their position. `status_column` is the field of the agents that holds their status. `nrows` is the number of times the model was run.
"""
function visualize_1DCA(data::DataFrame, model::AbstractModel, position_column::Symbol, status_column::Symbol, nrows::Integer; savename::AbstractString="CA_1D")
  dims = (model.space.dimensions[1], nrows)
  g = Agents.grid2D(dims[1], dims[2])
  locs_x, locs_y = node_locs(g, dims)
  
  # base node color is light grey
  nodefillc = [RGBA(0.1,0.1,0.1,.1) for i in 1:Agents.gridsize(dims)]

  for row in 1:nrows
    pos = Symbol(string(position_column)*"_$row")
    status = Symbol(string(status_column)*"_$row")
    newcolors = [RGBA(0.1, 0.1, 0.1, 0.01) for i in 1:dims[1]]
    for ll in 1:dims[1]
      if data[status][ll] == "1"
        newcolors[ll] = RGBA(0.1, 0.1, 0.1, 1.0)
      end
    end
    nodefillc[(dims[1]*row)-(dims[1]-1):dims[1]*row] .= newcolors
  end

  NODESIZE = 1/sqrt(gridsize(dims))
  draw(PDF("$savename.pdf"), gplot(g, locs_x, locs_y, nodefillc=nodefillc, edgestrokec=RGBA(0.1,0.1,0.1,0.01), NODESIZE=NODESIZE))

end

function visualize_2DCA(data::DataFrame, model::AbstractModel, position_column::Symbol, status_column::Symbol, runs::Integer; savename::AbstractString="CA_2D")
  dims = model.space.dimensions
  g = model.space.space
  locs_x, locs_y = node_locs(g, dims)
  NODESIZE = 1/sqrt(gridsize(dims))

  for r in 1:runs
    # base node color is light grey
    nodefillc = [RGBA(0.1,0.1,0.1,.1) for i in 1:Agents.gridsize(dims)]
    stat = Symbol(string(status_column)*"_$r")
    nonzeros = findall(a-> a =="1", data[stat])
    
    nodefillc[nonzeros] .= RGBA(0.1, 0.1, 0.1, 1)

    draw(PNG("$(savename)_$r.png"), gplot(g, locs_x, locs_y, nodefillc=nodefillc, edgestrokec=RGBA(0.1,0.1,0.1,0.01), NODESIZE=NODESIZE))
  end
end