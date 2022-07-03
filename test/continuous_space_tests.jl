using Agents, Test
using StableRNGs

@testset "ContinuousSpace" begin
    @agent SpeedyContinuousAgent ContinuousAgent{2} begin
        speed::Float64
    end

    @testset "space initialization" begin
        space1 = ContinuousSpace((1, 1))
        space2 = ContinuousSpace((1, 1, 1); spacing=0.25, periodic = false)
        @test_throws ArgumentError ContinuousSpace((-1,1)) # Cannot have negative extent
        @test_throws MethodError ContinuousSpace([1,1]) # Must be a tuple
        @test_throws MethodError ContinuousSpace((1, 1), 0.1) # spacing is a keyword
        model = ABM(SpeedyContinuousAgent, space1)
        model2 = ABM(SpeedyContinuousAgent, space2)
    end

    @testset "add/kill/move agent" begin
        space1 = ContinuousSpace((1, 1))
        model = ABM(SpeedyContinuousAgent, space1; rng = StableRNG(42))
        @test nagents(model) == 0
        # add_agent! with no existing agent (the agent is created)
        pos = (0.5, 0.5)
        vel = (0.2, 0.1)
        dia = 0.01
        agent = add_agent!(pos, model, vel, dia)
        @test collect(allids(model)) == [1]
        @test model[1].pos == agent.pos == (0.5, 0.5)
        # move_agent! without provided update_vel! function and using dt::Real
        move_agent!(agent, model, 1)
        @test agent.pos == (0.7, 0.6)
        # move_agent! with specified position
        move_agent!(agent, (0.5, 0.5), model)
        @test agent.pos == (0.5, 0.5)
        # move with random position
        move_agent!(agent, model)
        @test agent.pos ≠ (0.5, 0.5)
        # kill
        kill_agent!(agent, model)
        @test nagents(model) == 0
    end

    @testset "nearby ids" begin
        # At the end of this file there is a plotting test piece of code!
        # I've run it for many combinations and I am generally happy with the result.
        # I am sure we can improve it further, but that's for another time...
        extent = (1.0, 1.0)
        spacing = 0.1
        model = ABM(SpeedyContinuousAgent, ContinuousSpace(extent; spacing))
        # With this space size, the internal grid space which has size (10,10)
        # Hence, the "cell centers" from which search starts have positions:
        @testset "all cell centers" begin
            genocide!(model)
            # we can parallelize these cell center coordinates with the coordinates
            # in the documentation figure showing the different GridSpace metric types.
            cell_centers = [(0.05 + 0.1i, 0.05 + 0.1j) for i in 0:9, j in 0:9]
            for c in cell_centers
                add_agent!(c, model, (0.0, 0.0), 0.01)
            end
            center = (0.45, 0.45)
            center_id = 25
            rs = (1, 2, 3.4) .* 0.1 .+ 0.001 # multiply with spacing and add ε for accuracy
            ns = (4, 12, 36)
            for j in 1:3
                nids = nearby_ids_exact(center, model, rs[j])
                @test length(collect(nids)) == ns[j] + 1
                nids = nearby_agents_exact(model[center_id], model, rs[j])
                @test length(collect(nids)) == ns[j]
                nids = nearby_ids(center, model, rs[j])
                @test length(collect(nids)) ≥ ns[j] + 1
                nids = nearby_agents(model[center_id], model, rs[j])
                @test length(collect(nids)) ≥ ns[j]
            end
        end

        @testset "within same cell" begin
            genocide!(model)
            # Note that these two should NOT be in the same cell
            r0 = 0.01
            r1 = 0.08
            a = add_agent!((0.51, 0.51), model, (0.0, 0.0), 0.01)
            b = add_agent!((0.51 + r1, 0.51), model, (0.0, 0.0), 0.01)
            c1 = Agents.pos2cell(a, model)
            c2 = Agents.pos2cell(b, model)
            @test c1 == c2

            # Not true, but we are not using the exact method
            @test collect(nearby_ids(a, model, r0)) == [2]
            # Here it's empty:
            @test collect(nearby_ids_exact(a, model, r0)) == Int[]
            # and now all valid, and we use 1st clause of exact method (more than 1 cell)
            @test collect(nearby_ids(a, model, r1)) == [2]
            @test collect(nearby_ids_exact(a, model, r1)) == [2]
            # With position everything includes ID 1
            @test collect(nearby_ids(a.pos, model, r0)) == [1,2]
            @test collect(nearby_ids_exact(a.pos, model, r0)) == Int[1]
            @test collect(nearby_ids(a.pos, model, r1)) == [1,2]
            @test collect(nearby_ids_exact(a.pos, model, r1)) == [1,2]
        end
    end


    @testset "Interacting pairs" begin
        @testset "standard" begin
            space = ContinuousSpace((10, 10); spacing = 0.2, periodic = false)
            model = ABM(SpeedyContinuousAgent, space; scheduler = Schedulers.ByID())
            pos = [
                (7.074386436066224, 4.963014649338054)
                (5.831962448496828, 4.926297135685473)
                (5.122087781793935, 5.300031210394806)
                (3.9715633336430156, 4.8106570045816675)
            ]
            for i in 1:4
                add_agent_pos!(SpeedyContinuousAgent(i+2, pos[i], (0.0, 0.0), 0), model)
            end
            pairs = interacting_pairs(model, 2.0, :all).pairs
            @test length(pairs) == 5
            @test (3, 6) ∉ pairs

            space2 = ContinuousSpace((10, 10); spacing = 0.1, periodic = false)
            model2 = ABM(SpeedyContinuousAgent, space2; scheduler = Schedulers.ByID())
            for i in 1:4
                add_agent_pos!(SpeedyContinuousAgent(i, pos[i], (0.0, 0.0), 0), model2)
            end
            pairs = interacting_pairs(model2, 2.0, :nearest).pairs
            @test length(pairs) == 1
            pairs = interacting_pairs(model2, 2.5, :all).pairs
            @test length(pairs) == 5
            @test (1, 4) ∉ pairs
        end
        @testset "union types" begin
            mutable struct AgentU1 <: AbstractAgent
                id::Int
                pos::NTuple{2,Float64}
                vel::NTuple{2,Float64}
            end
            mutable struct AgentU2 <: AbstractAgent
                id::Int
                pos::NTuple{2,Float64}
                vel::NTuple{2,Float64}
            end
            function ignore_normal(model::ABM)
                [a.id for a in allagents(model) if !(typeof(a) <: SpeedyContinuousAgent)]
            end
            space3 = ContinuousSpace((10,10); spacing = 1.0, periodic = false)
            model3 = ABM(Union{SpeedyContinuousAgent, AgentU1, AgentU2}, space3; warn = false)
            for i in 1:10
                add_agent_pos!(SpeedyContinuousAgent(i, (i/10, i/10), (0.0, 0.0), 0), model3)
            end
            for i in 11:20
                add_agent_pos!(AgentU1(i, (i/10-1, 0.5), (0.0, 0.0)), model3)
            end
            for i in 21:30
                add_agent_pos!(AgentU2(i, (0.45, i/10-2), (0.0, 0.0)), model3)
            end
            pairs = interacting_pairs(model3, 0.1, :types).pairs
            @test length(pairs) == 7
            for (a,b) in pairs
                @test typeof(model3[a]) !== typeof(model3[b])
            end
            @test (3, 6) ∉ pairs

            # Test that we have at least some SpeedyContinuousAgent's in this match
            @test any(typeof(model3[a]) <: SpeedyContinuousAgent || typeof(model3[b]) <: SpeedyContinuousAgent for (a,b) in pairs)
            pairs = interacting_pairs(model3, 0.2, :types; scheduler = ignore_normal).pairs
            @test length(pairs) == 12
            # No SpeedyContinuousAgent's when using the ignore_normal scheduler
            @test all(!(typeof(model3[a]) <: SpeedyContinuousAgent) && !(typeof(model3[b]) <: SpeedyContinuousAgent) for (a,b) in pairs)
        end
        @testset "fix #288" begin
            space = ContinuousSpace((1,1); spacing = 0.1, periodic = true)
            model = ABM(SpeedyContinuousAgent, space)
            pos = [(0.01, 0.01),(0.2,0.2),(0.5,0.5)]
            for i in pos
            add_agent!(i,model,(0.0,0.0),1.0)
            end
            pairs = collect(interacting_pairs(model, 0.29, :all))
            @test length(pairs) == 1
            (a,b) = first(pairs)
            @test (a.id, b.id) == (1,2)
            # Before the #288 fix, this would return (2,3) as a pair
            # which has a euclidean distance of 0.42
            pairs = collect(interacting_pairs(model, 0.3, :all))
            @test length(pairs) == 1
            (a,b) = first(pairs)
            @test (a.id, b.id) == (1,2)
        end
    end

    @testset "nearest neighbor" begin
        mutable struct AgentNNContinuous <: AbstractAgent
            id::Int
            pos::NTuple{2,Float64}
            vel::NTuple{2,Float64}
            f1::Union{Int,Nothing}
        end
        space = ContinuousSpace((1,1); spacing = 0.1, periodic = true)
        model = ABM(AgentNNContinuous, space)
        pos = [(0.01, 0.01),(0.2, 0.01),(0.2, 0.2),(0.5, 0.5)]
        for i in pos
            add_agent!(i,model,(0.0,0.0),nothing)
        end

        for agent in allagents(model)
            agent.f1 = nearest_neighbor(agent, model, sqrt(2)).id
        end

        @test model[1].f1 == 2
        @test model[2].f1 == 1
        @test model[3].f1 == 2
        @test model[4].f1 == 3
    end
end


#=
using GLMakie, InteractiveDynamics
function test_neighbors_continuous(;
    extent = (1.0, 1.5)
    spacing = 0.05
    N = 1000
)
sizes = @. Int(extent/spacing)
c = spacing/2
model = ABM(SpeedyContinuousAgent, ContinuousSpace(extent; spacing))
cell_centers = [(c + spacing*i, 0.05 + spacing*j) for i in 0:sizes[1]-1, j in 0:sizes[2]-1]

# fill with random agents
for i in 1:N
    add_agent!(model, (0.0, 0.0), 0.0)
end

r = maximum(extent)*rand()/3
id0 = rand(1:N)
agent = model[id0]
pos0 = agent.pos
near_ids_exact = collect(nearby_ids_exact(agent, model, r))
near_ids = collect(nearby_ids(agent, model, r))
inexact = setdiff(near_ids, near_ids_exact) # only in inexact
interse = intersect(near_ids, near_ids_exact)

# create marker and color combinations
colors = fill(JULIADYNAMICS_COLORS[3], N)
markers = fill(:circle, N)
for id in 1:N
    if id == id0
        colors[id] = to_color(:red)
    elseif id ∈ interse
        colors[id] = JULIADYNAMICS_COLORS[2]
    elseif id ∈ inexact
        colors[id] = JULIADYNAMICS_COLORS[4]
        markers[id] = :rect
    elseif id ∈ near_ids_exact && id ∉ near_ids
        markers[id] = :diamond
        colors[id] = JULIADYNAMICS_COLORS[1]
    end
end

ac = (a) -> colors[a.id]
am = (a) -> markers[a.id]

static_preplot! = (ax, model) -> begin
    xs = 0:spacing:extent[1]
    vlines!(ax, xs; ymin = 0, ymax = extent[2], color = :gray)
    ys = 0:spacing:extent[2]
    hlines!(ax, ys; xmin = 0, xmax = extent[1], color = :gray)
    ax.title = "r = $r"
    scatter!(ax, vec(cell_centers); marker=:circle, color=:gray, markersize=5)
end

fig, ax = abmplot(model; static_preplot!, ac, am, as = 12)
display(fig)

# plot radius from agent
circ = [Point2f(cos(t)*r + pos0[1], sin(t)*r + pos0[2]) for t in range(0, 2π; length = 1000)]
poly!(ax, circ; color = RGBAf(0.3, 0.2, 0.4, 0.2),
strokecolor = RGBf(0.3, 0.2, 0.4), strokewidth = 1)
# plot radius from cell center
cc = Agents.cell_center(pos0, model)
circ = [Point2f(cos(t)*r + cc[1], sin(t)*r + cc[2]) for t in range(0, 2π; length = 1000)]
poly!(ax, circ; color = RGBAf(0.3, 0.2, 0.4, 0.0),
strokecolor = RGBf(0.3, 0.5, 0.4), strokewidth = 1, linestyle = :dash)
end
=#