# # Simulation games

# A Novel Approach to Interactive Agent-Based Models

# Interactive Agent-Based Models (ABMs) combine the power of agent-based modeling with the engaging nature of games to create immersive, interactive experiences that facilitate the understanding of complex systems. This novel approach to agent-based models allows users to actively participate in simulations, explore various scenarios, and observe the results of their actions in real-time.

# By bridging the gap between traditional agent-based modeling and gaming, simulation games not only provides an enjoyable way to learn and experiment with complex systems but also serves as an effective tool for education and research. For example:

# In ecology and conservation biology, researchers can use simulation games to investigate the impact of human activities on ecosystems, simulate species interactions, and evaluate the effectiveness of various conservation strategies.
# In the realm of social sciences, simulation games can be employed to explore human behavior, group dynamics, and social networks, enabling researchers to test different theories and observe how participants interact within various simulated environments.
# In education research, these interactive models can serve as valuable tools for investigating the effectiveness of game-based learning in enhancing students' understanding of complex topics and fostering critical thinking skills.

# In this example, we demonstrate a simple simulation game where the user controls a predator trying to catch preys in a grid-based environment. As the predator moves, the preys also move randomly across the grid.

# In this proof of concept, we have intentionally designed a simple example of a simulation game to demonstrate the potential and feasibility of interactive agent-based models.

# We start with the usual steps of building and ABM in Agents.jl, i.e. defining agent types and a function to initialize the model

using Agents

@agent Player GridAgent{2} begin end

@agent Prey GridAgent{2} begin
  destination::NTuple{2,Int}
end

"Initializes the model with the specified number of preys on a grid of the given dimensions."
function initialize_game(; dims=(100, 100), npreys=10, prey_speed=2)
  space = GridSpace(dims, periodic=false)
  model = ABM(Union{Player,Prey}, space, properties=Dict(:game_over => false, :speed => prey_speed))
  for z in 1:npreys
    prey = Prey(z, (1, 1), (rand(1:dims[1]), rand(1:dims[2])))
    add_agent_single!(prey, model)
  end
  player = Player(npreys + 1, (1, 1))
  add_agent_single!(player, model)
  return model
end
nothing # hide

# Next, we define a function to move the predator (player) in the specified direction. It takes care of the grid's boundaries, ensuring that the agent doesn't go out of bounds.

function walk_agent!(player::Player, model::ABM, direction::Symbol)
  new_pos = player.pos
  if direction == :up
    new_pos = (player.pos[1] - 1, player.pos[2])
  elseif direction == :down
    new_pos = (player.pos[1] + 1, player.pos[2])
  elseif direction == :left
    new_pos = (player.pos[1], player.pos[2] - 1)
  elseif direction == :right
    new_pos = (player.pos[1], player.pos[2] + 1)
  end
  if all(1 .<= new_pos .<= size(model.space))  # Valid position
    Agents.move_agent!(player, new_pos, model)
  end
end

walk_agent!(player::Player, model::ABM) = return
nothing # hide

# And a function for automatic movement of preys.
# This function calculates the distance between the current position and the destination, and moves the object towards the destination with the given speed. If the object is close enough to the destination (i.e., the distance is less than or equal to the speed), it will move directly to the destination. Otherwise, it will move a fraction of the distance based on the given speed. 

function move_towards_destination(pos::Tuple{Int,Int}, speed::Int, destination::Tuple{Int,Int})
  x1, y1 = pos
  x2, y2 = destination

  distance_x = x2 - x1
  distance_y = y2 - y1

  total_distance = sqrt(distance_x^2 + distance_y^2)

  if total_distance <= speed
    return destination
  end

  angle = atan(distance_y, distance_x)
  new_x = x1 + round(Int, speed * cos(angle))
  new_y = y1 + round(Int, speed * sin(angle))

  ## If rounding causes the position to overshoot the destination, clamp to the destination
  new_x = (distance_x > 0 ? min(new_x, x2) : max(new_x, x2))
  new_y = (distance_y > 0 ? min(new_y, y2) : max(new_y, y2))

  return (new_x, new_y)
end
nothing # hide

# When preys reach their destination, they choose a new random destination. 

function walk_agent!(player::Prey, model::ABM)
  dims = size(model.space)
  new_pos = move_towards_destination(player.pos, model.speed, player.destination)
  if new_pos == player.destination
    player.destination = (rand(1:dims[1]), rand(1:dims[2]))
  end
  Agents.move_agent!(player, new_pos, model)
end

function move_preys!(model::ABM)
  for (zid, z) in model.agents
    walk_agent!(z, model)
  end
end
nothing # hide

# The interactivity of the model is achieved using `Makie.jl`. We use a simple scatter plot and bind one point to the keyboard so the user can move it around.

using Makie
using GLMakie
using Observables

# The `update_point!()` function updates the position of a point (predator or prey) in the scatter plot. This function is used to visualize the movement of agents on the grid.

"""
Update the position of point `index`.
"""
function update_point!(points, index, new_point)
  current_points = copy(points[])
  current_points[index] = new_point
  points[] = current_points
end
nothing # hide


# The `main()` function sets up the game, creates the scatter plot for visualizing the agents, and handles user input for controlling the predator's movement. The predator moves according to the arrow keys, and the game continues indefinitely. In this first example, no interactions happen between the predator and preys.

function main()
  GLMakie.inline!(false) # Add this line to run the plot on a separate thread

  model = initialize_game()
  dims = size(model.space)

  total_agents = nagents(model)
  player = model[total_agents]

  ## Create a scatter plot and add the player
  player_scatter = scatter([player.pos[2]], [player.pos[1]], markersize=10, color=:blue, padding=0)

  ## Add preys to the plot
  positions = [getproperty(model[i], :pos) for i in 1:(total_agents-1)]
  ## Create an observable array of points, which can then be updated in real-time
  points = Observable(positions)
  scatter!(points, color=:red)

  axis = player_scatter.axis
  scene = axis.scene
  limits!(axis, FRect(0, 0, dims[1], dims[2]))

  function handle_key(scene, key)
    if key == Makie.Keyboard.down
      walk_agent!(player, model, :up)
    elseif key == Makie.Keyboard.up
      walk_agent!(player, model, :down)
    elseif key == Makie.Keyboard.left
      walk_agent!(player, model, :left)
    elseif key == Makie.Keyboard.right
      walk_agent!(player, model, :right)
    end

    ## Update the scatter plot's data with the new player position
    player_scatter.plot.positions[] = [Point2f0(player.pos[2], player.pos[1])]
  end

  ## Wrap the while loop in an async block
  ## using an async task for the while loop allows the loop to run concurrently with the rest of the code. Without it, the while loop would block the main thread, preventing the user from interacting with the game.
  async_loop = @async begin
    while model.game_over == false
      sleep(0.2)
      move_preys!(model) ## updates the positions of preys in the model.
      for index in 1:(total_agents-1)
        update_point!(points, index, model[index].pos) ## update the position of preys on the scatter plot
      end
    end
  end

  on(events(scene).keyboardbutton) do event
    if event.action == Keyboard.press || event.action == Keyboard.repeat
      handle_key(scene, event.key)
    end
  end

  display(scene)
  wait(async_loop) ## wait for the async_loop to finish before ending the main function
end
nothing # hide

# One can easily add more complex behavior to the model. For example, the preys die if the predator comes close to them.

function update_agent_point!(points, agent_id, point_indices, new_point, remove=false)
  index = point_indices[agent_id]
  current_points = copy(points[])
  if remove
    deleteat!(current_points, index)
    delete!(point_indices, agent_id)
    for id in keys(point_indices)
      if point_indices[id] > index
        point_indices[id] -= 1
      end
    end
  else
    current_points[index] = new_point
  end
  points[] = current_points
end
nothing # hide

function check_contact(player, model)
  all_ids = collect(nearby_ids(player, model, 3))
  if length(all_ids) > 0
    for i in all_ids
      return i  ## only one contact per time
    end
  end
  return -1
end
nothing # hide


function main2()
  GLMakie.inline!(false) ## Add this line to run the plot on a separate thread

  model = initialize_game()
  dims = size(model.space)

  total_agents = nagents(model)
  player = model[total_agents]

  ## Create a scatter plot and add the player
  player_scatter = scatter([player.pos[2]], [player.pos[1]], markersize=10, color=:blue, padding=0)

  ## Add preys to the plot
  point_indices = Dict(model[i].id => i for i in 1:(total_agents-1))
  ## Create an observable array of points, which can then be updated in real-time
  points = Observable([getproperty(model[point_indices[i]], :pos) for i in 1:(total_agents-1)])
  scatter!(points, color=:red)

  axis = player_scatter.axis
  scene = axis.scene
  limits!(axis, FRect(0, 0, dims[1], dims[2]))

  function handle_key(scene, key)
    if key == Makie.Keyboard.down
      walk_agent!(player, model, :up)
    elseif key == Makie.Keyboard.up
      walk_agent!(player, model, :down)
    elseif key == Makie.Keyboard.left
      walk_agent!(player, model, :left)
    elseif key == Makie.Keyboard.right
      walk_agent!(player, model, :right)
    end

    ## Check for contact
    collided_index = check_contact(player, model)
    if collided_index != -1
      collided_id = model[collided_index].id
      kill_agent!(collided_index, model)
      update_agent_point!(points, collided_id, point_indices, (0, 0), true)
    end

    ## Update the scatter plot's data with the new player position
    player_scatter.plot.positions[] = [Point2f0(player.pos[2], player.pos[1])]
  end

  ## Wrap the while loop in an async block
  async_loop = @async begin
    while model.game_over == false
      sleep(0.2)
      move_preys!(model) ## updates the positions of preys in the model.
      for agent_id in keys(point_indices)
        update_agent_point!(points, agent_id, point_indices, model[agent_id].pos)
      end

      ## Check for contact
      collided_index = check_contact(player, model)
      if collided_index != -1
        collided_id = model[collided_index].id
        kill_agent!(collided_index, model)
        update_agent_point!(points, collided_id, point_indices, (0, 0), true)
      end

      if nagents(model) == 1
        model.game_over = true
      end
    end
  end

  on(events(scene).keyboardbutton) do event
    if event.action == Keyboard.press || event.action == Keyboard.repeat
      handle_key(scene, event.key)
    end
  end

  display(scene)
  wait(async_loop) ## wait for the async_loop to finish before ending the main function
end
nothing # hide

