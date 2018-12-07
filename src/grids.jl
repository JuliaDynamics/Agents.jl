# A grid can be 0D (a node), 1D (a line of nodes), 2D (a surface of nodes) or 3D (a surface of nodes with values at each node).

function grid0D()
end

function grid1D(length::Integer)
  g = PathGraph(length)
end

function grid2D(n::Integer, m::Integer)
  g = Grid([n, m])
end

function grid3D()
  #TODO
end