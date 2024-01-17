using Test, Agents, Random
using Agents.Graphs, Agents.DataFrames
using StableRNGs

# TODO: All of these tests are "bad" in the sense that they should be moved
# to individual space test files.
@testset "add_agent! (discrete space)" begin
    properties = Dict(:x1 => 1)
    space = GraphSpace(complete_digraph(10))
    model = StandardABM(Agent7, space; properties, warn_deprecation = false)
    attributes = (f1 = true, f2 = 1)
    add_agent!(1, model, attributes...)
    attributes = (f2 = 1, f1 = true)
    add_agent!(1, model; attributes...)
    @test model[1].id != model[2].id
    @test model[1].pos == model[2].pos
    @test model[1].f1 == model[2].f1
    @test model[1].f2 == model[2].f2
    @test add_agent_single!(model, attributes...).pos ∈ 1:10
    a = Agent7(model, 1, attributes...)
    @test add_agent_single!(a, model).pos ∈ 1:10
    fill_space!(model, attributes...)
    @test !has_empty_positions(model)
    add_agent_single!(Agent7, model, attributes...)
    @test_throws KeyError model[22]
    a = add_agent!(Agent7, model, attributes...)
    @test a.pos ∈ 1:10

    @test add_agent!(3, Agent7, model, attributes...).pos == 3
    a = Agent7(model, 3, attributes...)
    @test add_agent_own_pos!(a, model).pos == 3

    model = StandardABM(Agent1, GridSpace((10, 10)), warn_deprecation = false)
    @test add_agent!((7, 8), Agent1, model).pos == (7, 8)
    a = Agent1(model; pos = (9, 8))
    @test add_agent_own_pos!(a, model).pos == (9, 8)
end

@testset "add_agent! (nothing space)" begin
    model = StandardABM(Agent0, warn_deprecation = false)
    @test add_agent!(model).id == 1
    a = Agent0(model)
    @test add_agent_own_pos!(a, model).id == 2
end

@testset "move_agent!" begin
    # GraphSpace
    model = StandardABM(Agent5, GraphSpace(path_graph(6)), warn_deprecation = false)
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
    model = StandardABM(Agent1, GridSpace((5, 5)), warn_deprecation = false)
    agent = add_agent!((2, 4), model)
    move_agent!(agent, (1, 3), model)
    @test agent.pos == (1, 3)
    ni = 0
    init_pos = agent.pos
    while agent.pos == init_pos
        move_agent!(agent, model)
    end
    @test ni < Inf

    model = StandardABM(Agent1, GridSpace((2, 1)), warn_deprecation = false)
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
    model = StandardABM(NoSpaceAgent, warn_deprecation = false)
    add_agent!(model)
    agent = add_agent!(model)
    @test nagents(model) == 2
    remove_agent!(agent, model)
    @test nagents(model) == 1
    add_agent!(model)
    remove_all!(model, [1, 3])
    @test nagents(model) == 0
    # GraphSpace
    model = StandardABM(Agent5, GraphSpace(path_graph(6)), warn_deprecation = false)
    add_agent!(model, 5.3)
    add_agent!(model, 2.7)
    @test nagents(model) == 2
    remove_agent!(model[1], model)
    @test nagents(model) == 1
    remove_agent!(2, model)
    @test nagents(model) == 0
    # GridSpace
    model = StandardABM(Agent1, GridSpace((5, 5)), warn_deprecation = false)
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
    model = StandardABM(NoSpaceAgent, container = Vector, warn_deprecation = false)
    add_agent!(model)
    agent = add_agent!(model)
    @test agent.id == 2
    @test nagents(model) == 2
    @test_throws ErrorException remove_agent!(agent, model)
    @test_throws ErrorException remove_all!(model, [1, 3])
    # GraphSpace
    model = StandardABM(Agent5, GraphSpace(path_graph(6)), container = Vector, warn_deprecation = false)
    add_agent!(model, 5.3)
    add_agent!(model, 2.7)
    @test nagents(model) == 2
    @test_throws ErrorException remove_agent!(model[1], model)
end

@testset "remove_all!" begin
    # Testing no space
    model = StandardABM(NoSpaceAgent, warn_deprecation = false)
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

    model = StandardABM(GridAgent{2}, GridSpace((10, 10)), warn_deprecation = false)
    # Testing remove_all!(model::ABM)
    for i in 1:20
        add_agent_single!(GridAgent{2}, model)
    end
    remove_all!(model)
    @test nagents(model) == 0
    @test all(p -> isempty(p, model), positions(model)) == true

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

    model = StandardABM(GridAgent{2}, GridSpaceSingle((10, 10)), warn_deprecation = false)
    for i in 1:20
        add_agent_single!(GridAgent{2}, model)
    end
    remove_all!(model)
    @test nagents(model) == 0
    @test all(p -> isempty(p, model), positions(model)) == true

    model = StandardABM(ContinuousAgent{2, Float64}, ContinuousSpace((10, 10)), warn_deprecation = false)
    for i in 1:20
        add_agent!(ContinuousAgent{2, Float64}, model, SVector(10*rand(), 10*rand()))
    end
    remove_all!(model)
    @test nagents(model) == 0
    @test all(p -> isempty(p, abmspace(model).grid), positions(abmspace(model).grid)) == true

end

@agent struct Daisy(GridAgent{2})
    breed::String
end
@agent struct Land(GridAgent{2})
    temperature::Float64
end
@testset "fill space" begin
    space = GridSpace((10, 10))
    model = StandardABM(Land, space, warn_deprecation = false)
    fill_space!(model, 15)
    @test nagents(model) == 100
    for a in allagents(model)
        @test a isa Land
        @test a.temperature == 15
    end

    space = GridSpace((10, 10))
    model = StandardABM(Union{Daisy,Land}, space; warn = false, warn_deprecation = false)
    fill_space!(Daisy, model, "black")
    @test nagents(model) == 100
    for a in allagents(model)
        @test a isa Daisy
        @test a.breed == "black"
    end

    space = GridSpace((10, 10), periodic = true)
    model = StandardABM(Union{Daisy,Land}, space; warn = false, warn_deprecation = false)
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

    for agents_first in (true, false)
        model = StandardABM(Agent2; agent_step!, model_step!,
                    properties = Dict(:count => 0), agents_first = agents_first)
        for i in 1:100
            add_agent!(model, rand(abmrng(model)))
        end
        step!(model, 1)
        if agents_first
            @test model.count == 100
        else
            @test model.count == 0
        end
    end
end

@testset "model time updates" begin
    model_step!(model) = nothing
    agent_step!(a, model) = nothing
    f(model, t) = t > 100
    model = StandardABM(Agent2; agent_step!, model_step!)
    @test abmtime(model) == 0
    step!(model, 1)
    @test abmtime(model) == 1
    step!(model, 10)
    @test abmtime(model) == 11
    step!(model, f)
    @test abmtime(model) == 112
end

@testset "Higher order groups" begin
    @agent struct AgentWithWeight(GridAgent{2})
        weight::Float64
    end

    model = StandardABM(AgentWithWeight, GridSpace((10, 10)); scheduler = Schedulers.ByID(), warn_deprecation = false)
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
    model = StandardABM(Agent8, ContinuousSpace((5, 5)), warn_deprecation = false)
    a = Agent8(1, (2.0, 2.0), (1.0, 1.0), true, 1)
    b = replicate!(a, model)
    @test b.pos == a.pos && b.f1 == a.f1 && b.f2 == a.f2
    c = replicate!(a, model; f2 = 2)
    @test c.pos == a.pos && c.f1 == a.f1 && c.f2 == 2
    d = replicate!(a, model; f1 = false, f2 = 2)
    @test d.pos == a.pos && d.f1 == false && d.f2 == 2
end

@testset "swap_agents!" begin
    # GraphSpace
    model = StandardABM(Agent5, GraphSpace(path_graph(6)), warn_deprecation = false)
    agent1 = add_agent!(model, 5.3)
    agent2 = add_agent!(model, 9.9)
    pos_a, pos_b = agent1.pos, agent2.pos
    swap_agents!(agent1, agent2, model)
    @test agent2.pos == pos_a
    @test agent1.pos == pos_b
    @test agent2.weight == 9.9
    @test agent1.weight == 5.3

    # GridSpace
    model = StandardABM(Agent1, GridSpace((5, 5)), warn_deprecation = false)
    agent1 = add_agent!((2, 4), model)
    agent2 = add_agent!((1, 3), model)
    swap_agents!(agent1, agent2, model)
    @test agent1.pos == (1, 3)
    @test agent2.pos == (2, 4)
end

@testset "@compact macro" begin

    @multiagent struct Animal{T,N,J}(GridAgent{2})
        @agent struct Wolf{T,N}
            energy::T = 0.5
            ground_speed::N
            const fur_color::Symbol
        end
        @agent struct Hawk{T,N,J}
            energy::T = 0.1
            ground_speed::N
            flight_speed::J
        end
    end

    hawk_1 = Hawk(1, (1, 1), 1.0, 2.0, 3)
    hawk_2 = Hawk(; id = 2, pos = (1, 2), ground_speed = 2.3, flight_speed = 2)
    wolf_1 = Wolf(3, (2, 2), 2.0, 3.0, :black)
    wolf_2 = Wolf(; id = 4, pos = (2, 1), ground_speed = 2.0, fur_color = :white)

    @test hawk_1.energy == 1.0
    @test hawk_2.energy == 0.1
    @test wolf_1.energy == 2.0
    @test wolf_2.energy == 0.5
    @test hawk_1.flight_speed == 3
    @test hawk_2.flight_speed == 2
    @test wolf_1.fur_color == :black
    @test wolf_2.fur_color == :white
    @test_throws "" hawk_1.fur_color
    @test_throws "" wolf_1.flight_speed
    @test hawk_1.type == hawk_2.type == :hawk
    @test wolf_1.type == wolf_2.type == :wolf

    @multiagent struct A{T}(NoSpaceAgent)
        @agent struct B{T}
            a::T = 1
            b::Int
            c::Symbol
        end
        @agent struct C
            b::Int = 2
            c::Symbol
            d::Vector{Int}
        end
        @agent struct D{T}
            c::Symbol = :k
            d::Vector{Int}
            a::T
        end
    end

    b1 = B(1, 2, 1, :s)
    c1 = C(1, 1, :s, Int[])
    d1 = D(1, :s, [1], 1.0)
    b2 = B(; id = 1, b = 1, c = :s)
    c2 = C(; id = 1, c = :s, d = [1,2])
    d2 = D(; id = 1, d = [1], a = true)

    @test b2.a == 1
    @test c2.b == 2
    @test d2.c == :k
    @test b1.type == b2.type == :b
    @test c1.type == c2.type == :c
    @test d1.type == d2.type == :d
    @test_throws "" b2.d
    @test_throws "" c1.a
    @test_throws "" d1.b
    @test d2.a == true
    @test b2.c == c2.c == b1.c == c1.c == d1.c == :s
    @test b1 isa A && b2 isa A
    @test c1 isa A && c2 isa A
    @test d1 isa A && d2 isa A

    fake_step!(a) = nothing
    model = StandardABM(A, agent_step! = fake_step!)

    add_agent!(B, model, 2, 1, :s)
    add_agent!(C, model, 1, :s, Int[])
    add_agent!(D, model, :s, [1], 1.0)
    @test nagents(model) == 3

    abstract type AbstractE <: AbstractAgent end
    @multiagent struct E(NoSpaceAgent) <: AbstractE
        @agent struct A
            x::Int
        end
        @agent struct B
            y::Int
        end
    end

    a = A(1, 1)
    b = B(2, 2)

    @test a.id == 1
    @test b.id == 2
    @test a.x == 1
    @test b.y == 2
    @test_throws "" a.y
    @test_throws "" b.x
    @test a.type == :a
    @test b.type == :b
    @test E <: AbstractE && E <: AbstractE
    @test a isa E && b isa E

end
