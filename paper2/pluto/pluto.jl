### A Pluto.jl notebook ###
# v0.9.5

using Markdown
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.peek, el) ? Base.peek(el) : missing
        el
    end
end

# ╔═╡ 00e04cb2-aa40-11ea-3834-c75335766ef5
begin
using Agents
using Random
using PlutoUI
using AgentsPlots
end

# ╔═╡ 5010f960-aa40-11ea-3675-bf6b5c4eb0db
begin
mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Bool  # true is green and false is burning
end

function model_initiation(; f = 0.02, d = 0.8, p = 0.01, griddims = (100, 100), seed = 111)
    Random.seed!(seed)
    space = GridSpace(griddims, moore = true)
    properties = Dict(:f => f, :d => d, :p => p)
    forest = AgentBasedModel(Tree, space; properties = properties)

    # create and add trees to each node with probability d,
    # which determines the density of the forest
    for node in nodes(forest)
        if rand() ≤ forest.d
            add_agent!(node, forest, true)
        end
    end
    return forest
end

function forest_step!(forest)
    for node in nodes(forest, by = :random)
        nc = get_node_contents(node, forest)
        # the cell is empty, maybe a tree grows here
        if length(nc) == 0
            rand() ≤ forest.p && add_agent!(node, forest, true)
        else
            tree = forest[nc[1]] # by definition only 1 agent per node
            if tree.status == false  # if it is has been burning, remove it.
                kill_agent!(tree, forest)
            else
                if rand() ≤ forest.f  # the tree ignites spontaneously
                    tree.status = false
                else  # if any neighbor is on fire, set this tree on fire too
                    for cell in node_neighbors(node, forest)
                        neighbors = get_node_contents(cell, forest)
                        length(neighbors) == 0 && continue
                        if any(n -> !forest.agents[n].status, neighbors)
                            tree.status = false
                            break
                        end
                    end
                end
            end
        end
    end
end

function ngreen(model)
	counter = 0
	for ag in values(model.agents)
		if ag.status == true
			counter += 1
		end
	end
	counter
end

end

# ╔═╡ c83b74b2-aa40-11ea-101e-b97a99fa11bb
md"""
f: $(@bind f Slider(0.01:0.01:1.0))
d: $(@bind d Slider(0.01:0.01:1.0))
p: $(@bind p Slider(0.01:0.01:1.0))
"""

# ╔═╡ a6a19e60-aa40-11ea-2922-932e7be0ebab
forest = model_initiation(f = f, d = d, p = p, griddims = (20, 20), seed = 2)

# ╔═╡ 8a07d760-aa40-11ea-1e67-1bf142c9b709
step!(forest, dummystep, forest_step!, 20)

# ╔═╡ 486f47b0-aa41-11ea-1bc7-ab3204d4e945
ngreen(forest)

# ╔═╡ 07257ed2-aa43-11ea-22a4-ed981abf1529
treecolor(a) = a.status == 1 ? :green : :red

# ╔═╡ 6e1c66e0-aa42-11ea-1f24-033eeafccb2d
plotabm(forest; ac = treecolor, ms = 6, msw = 0)

# ╔═╡ Cell order:
# ╠═00e04cb2-aa40-11ea-3834-c75335766ef5
# ╠═5010f960-aa40-11ea-3675-bf6b5c4eb0db
# ╠═c83b74b2-aa40-11ea-101e-b97a99fa11bb
# ╠═a6a19e60-aa40-11ea-2922-932e7be0ebab
# ╠═8a07d760-aa40-11ea-1e67-1bf142c9b709
# ╠═486f47b0-aa41-11ea-1bc7-ab3204d4e945
# ╠═6e1c66e0-aa42-11ea-1f24-033eeafccb2d
# ╠═07257ed2-aa43-11ea-22a4-ed981abf1529
