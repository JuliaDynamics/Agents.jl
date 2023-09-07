using Test, Agents, Random
using Agents.Graphs, Agents.DataFrames
using StableRNGs

# TODO: All of these tests are "bad" in the sense that they should be moved
# to individual space test files.
@testset "add_agent! (discrete)" begin
    properties = Dict(:x1 => 1)
    space = GraphSpace(complete_digraph(10))
    model = ABM(Agent7, space; properties)
    attributes = (f1 = true, f2 = 1)
    add_agent!(1, model, attributes...)
    attributes = (f2 = 1, f1 = true)
    add_agent!(1, model; attributes...)
    @test model[1].id != model[2].id
    @test model[1].pos == model[2].pos
    @test model[1].f1 == model[2].f1
    @test model[1].f2 == model[2].f2
    @test add_agent_single!(model, attributes...).pos ∈ 1:10
    fill_space!(model, attributes...)
    @test !has_empty_positions(model)
    add_agent_single!(Agent7, model, attributes...)
    @test_throws KeyError model[22]
    add_agent!(Agent7, model, attributes...)
    @test model[22].pos ∈ 1:10

    @test add_agent!(3, Agent7, model, attributes...).pos == 3

    model = ABM(Agent1, GridSpace((10, 10)))
    @test add_agent!((7, 8), Agent1, model).pos == (7, 8)
end

@testset "move_agent!" begin
    # GraphSpace
    model = ABM(Agent5, GraphSpace(path_graph(6)))
    agent = add_agent!(model, 5.3)
    init_pos = agent.pos
    # Checking specific indexing
    move_agent!(agent, rand(abmrng(model), [i for i in 1:6 if i != init_pos]), model)
    new_pos = agent.pos
    @test new_pos != init_pos
    # Checking a random move
    ni = 0
    init_pos = agent.pos
    while agent.pos == init_pos
        move_agent!(agent, model)
    end
    @test ni < Inf

    # GridSpace
    model = ABM(Agent1, GridSpace((5, 5)))
    agent = add_agent!((2, 4), model)
    move_agent!(agent, (1, 3), model)
    @test agent.pos == (1, 3)
    ni = 0
    init_pos = agent.pos
    while agent.pos == init_pos
        move_agent!(agent, model)
    end
    @test ni < Inf

    model = ABM(Agent1, GridSpace((2, 1)))
    agent = add_agent!((1, 1), model)
    move_agent_single!(agent, model)
    @test agent.pos == (2, 1)
    agent2 = add_agent!((1, 1), model)
    move_agent_single!(agent2, model)
    # Agent shouldn't move since the grid is saturated
    @test agent2.pos == (1, 1)
end

@testset "remove_agent!" begin
    # No Space
    model = ABM(NoSpaceAgent)
    add_agent!(model)
    agent = add_agent!(model)
    @test nagents(model) == 2
    remove_agent!(agent, model)
    @test nagents(model) == 1
    add_agent!(model)
    remove_all!(model, [1, 3])
    @test nagents(model) == 0
    # GraphSpace
    model = ABM(Agent5, GraphSpace(path_graph(6)))
    add_agent!(model, 5.3)
    add_agent!(model, 2.7)
    @test nagents(model) == 2
    remove_agent!(model[1], model)
    @test nagents(model) == 1
    remove_agent!(2, model)
    @test nagents(model) == 0
    # GridSpace
    model = ABM(Agent1, GridSpace((5, 5)))
    add_agent!((1, 3), model)
    add_agent!((1, 3), model)
    add_agent!((5, 2), model)
    @test nagents(model) == 3
    for id in copy(ids_in_position((1, 3), model))
        remove_agent!(id, model)
    end
    @test nagents(model) == 1
end

@testset "remove_agent! (vector container)" begin
    # No Space
    model = UnremovableABM(NoSpaceAgent)
    add_agent!(model)
    agent = add_agent!(model)
    @test agent.id == 2
    @test_throws ErrorException add_agent!(NoSpaceAgent, model)
    @test nagents(model) == 2
    @test_throws ErrorException remove_agent!(agent, model)
    @test_throws ErrorException remove_all!(model, [1, 3])
    # GraphSpace
    model = UnremovableABM(Agent5, GraphSpace(path_graph(6)))
    add_agent!(model, 5.3)
    add_agent!(model, 2.7)
    @test nagents(model) == 2
    @test_throws ErrorException remove_agent!(model[1], model)
end

@testset "remove_all!" begin
    # Testing no space
    model = ABM(NoSpaceAgent)
    for i in 1:10
        add_agent!(NoSpaceAgent, model)
    end
    remove_all!(model)
    @test nagents(model) == 0
    for i in 1:10
        add_agent!(NoSpaceAgent, model)
    end
    remove_all!(model, 5)
    @test nagents(model) == 5
    remove_all!(model, a -> a.id < 3)
    @test nagents(model) == 3

    model = ABM(GridAgent{2}, GridSpace((10, 10)))

    # Testing remove_all!(model::ABM)
    for i in 1:20
        add_agent_single!(GridAgent{2}, model)
    end
    remove_all!(model)
    @test nagents(model) == 0

    # Testing remove_all!(model::ABM, n::Int)
    for i in 1:20
        # Explicitly override agents each time we replenish the population,
        # so we always start the remove_all with 20 agents.
        add_agent_single!(GridAgent{2}, model)
    end
    remove_all!(model, 10)
    @test nagents(model) == 10

    # Testing remove_all!(model::ABM, f::Function) with an anonymous function
    for i in 11:20
        add_agent_single!(GridAgent{2}, model)
    end
    @test nagents(model) == 20
    remove_all!(model, a -> a.id > 5)
    @test nagents(model) == 5

end

mutable struct Daisy <: AbstractAgent
    id::Int
    pos::Dims{2}
    breed::String
end
mutable struct Land <: AbstractAgent
    id::Int
    pos::Dims{2}
    temperature::Float64
end
@testset "fill space" begin
    space = GridSpace((10, 10))
    model = ABM(Land, space)
    fill_space!(model, 15)
    @test nagents(model) == 100
    for a in allagents(model)
        @test a isa Land
        @test a.temperature == 15
    end

    space = GridSpace((10, 10))
    model = ABM(Union{Daisy,Land}, space; warn = false)
    fill_space!(Daisy, model, "black")
    @test nagents(model) == 100
    for a in allagents(model)
        @test a isa Daisy
        @test a.breed == "black"
    end

    space = GridSpace((10, 10), periodic = true)
    model = ABM(Union{Daisy,Land}, space; warn = false)
    temperature(pos) = (pos[1] / 10,) # make it Tuple!
    fill_space!(Land, model, temperature)
    @test nagents(model) == 100
    for a in allagents(model)
        @test a.temperature == a.pos[1] / 10
    end

end

@testset "model step order" begin
    function model_step!(model)
        for a in allagents(model)
            if a.weight > 1.0
                model.count += 1
            end
        end
    end
    function agent_step!(a, model)
        a.weight += 1
    end

    for bool in (true, false)
        model = ABM(Agent2; properties = Dict(:count => 0))
        for i in 1:100
            add_agent!(model, rand(abmrng(model)))
        end
        step!(model, agent_step!, model_step!, 1, bool)
        if bool
            @test model.count == 100
        else
            @test model.count == 0
        end
    end
end

@testset "Higher order groups" begin
    mutable struct AgentWithWeight <: AbstractAgent
        id::Int
        pos::Dims{2}
        weight::Float64
    end

    model = ABM(AgentWithWeight, GridSpace((10, 10)); scheduler = Schedulers.ByID())
    for i in 1:10
        add_agent!(model, i)
    end

    iter_second_ids = map(x -> (x[1].id, x[2].id), iter_agent_groups(2, model))
    @test size(iter_second_ids) == (10, 10)
    @test iter_second_ids[1] == (1, 1)
    @test iter_second_ids[15] == (5, 2)
    @test iter_second_ids[end] == (10, 10)

    second = collect(map_agent_groups(2, x -> x[1].weight + x[2].weight, model))
    @test size(second) == (10, 10)
    @test second[1] == 2.0
    @test second[15] == 7.0
    @test second[end] == 20.0

    third =
        collect(map_agent_groups(3, x -> x[1].weight + x[2].weight + x[3].weight, model))
    @test size(third) == (10, 10, 10)
    @test third[1] == 3.0
    @test third[15] == 8.0
    @test third[end] == 30.0

    second_filtered =
        collect(map_agent_groups(2, x -> x[1].weight + x[2].weight, model, allunique))
    @test size(second_filtered) == (90,)
    @test second_filtered[1] == 3.0
    @test second_filtered[15] == 9.0
    @test second_filtered[end] == 19.0

    idx_second_filtered = collect(index_mapped_groups(2, model, allunique))
    @test size(idx_second_filtered) == (90,)
    @test idx_second_filtered[1] == (2, 1)
    @test idx_second_filtered[15] == (7, 2)
    @test idx_second_filtered[end] == (9, 10)
end

@testset "replicate!" begin
    model = ABM(Agent8, ContinuousSpace((5, 5)))
    a = Agent8(1, (2.0, 2.0), (1.0, 1.0), true, 1)
    b = replicate!(a, model)
    @test b.pos == a.pos && b.f1 == a.f1 && b.f2 == a.f2
    c = replicate!(a, model; f2 = 2)
    @test c.pos == a.pos && c.f1 == a.f1 && c.f2 == 2
    d = replicate!(a, model; f1 = false, f2 = 2)
    @test d.pos == a.pos && d.f1 == false && d.f2 == 2
end
