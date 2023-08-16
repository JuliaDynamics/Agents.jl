using Agents, Test
using StableRNGs
using StaticArrays
using LinearAlgebra: norm, dot

# TODO: We need to write tests for get_spatial_index and stuff!

@testset "ContinuousSpace" begin
    @agent SpeedyContinuousAgent ContinuousAgent{2} begin
        speed::Float64
    end

    @testset "space initialization" begin
        space1 = ContinuousSpace((1, 1))
        space2 = ContinuousSpace((1, 1, 1); spacing=0.25, periodic = false)
        @test spacesize(space1) == SVector(1.0, 1.0)
        @test spacesize(space2) == SVector(1.0, 1.0, 1.0)
        @test_throws ArgumentError ContinuousSpace((-1,1)) # Cannot have negative extent
        @test_throws MethodError ContinuousSpace([1,1]) # Must be a tuple or svector
        model = ABM(SpeedyContinuousAgent, space1)
        model2 = ABM(SpeedyContinuousAgent, space2)
    end

    @testset "add/remove/move agent" begin
        space1 = ContinuousSpace((1, 1))
        model = ABM(SpeedyContinuousAgent, space1; rng = StableRNG(42))
        @test nagents(model) == 0
        # add_agent! with no existing agent (the agent is created)
        pos0 = SVector(0.51, 0.51)
        vel = SVector(0.2, 0.1)
        dia = 0.01
        agent = add_agent!(pos0, model, vel, dia)
        @test collect(allids(model)) == [1]
        @test model[1].pos == agent.pos == pos0
        # move_agent! without provided update_vel! function and using dt::Real
        move_agent!(agent, model, 1)
        @test agent.pos == SVector(0.71, 0.61)
        # move_agent! with specified position
        move_agent!(agent, pos0, model)
        @test agent.pos == pos0
        # Do it twice to ensure it works if agent stays in same cell
        move_agent!(agent, pos0, model)
        @test agent.pos == pos0
        # move with random position
        move_agent!(agent, model)
        @test agent.pos ≠ pos0
        # move at position OUTSIDE extend. Must lead to invalid position
        @test_throws ErrorException move_agent!(agent, SVector(1.5, 1.5), model)
        # remove
        remove_agent!(agent, model)
        @test nagents(model) == 0
    end

    @testset "support for ntuples after #846" begin
        # agents with SVector types also work when passing tuples to functions
        @agent SVecAgent ContinuousAgent{2} begin; end
        space = ContinuousSpace((1,1))
        model = ABM(SVecAgent, space)
        x = (0.0, 0.0)
        v = (0.1, 0.0)
        dt = 1.0
        add_agent!(x, model, v)
        @test model[1].pos == SVector(x)
        @test model[1].vel == SVector(v)
        # different types of motion
        move_agent!(model[1], model, dt)
        @test model[1].pos == SVector(x .+ v.*dt)
        y = (0.5, 0.2)
        move_agent!(model[1], y, model)
        @test model[1].pos == SVector(y)
        walk!(model[1], 2 .* model[1].vel, model)
        @test model[1].pos == SVector(y .+ 2 .* v)
        # agent addition works also if pos is not specified
        add_agent!(model, .-v)
        @test model[2].pos isa SVector{2,Float64}
        @test model[2].vel == SVector(.-v)

        # agents with hard-coded tuple types should work but throw warnings on creation
        mutable struct TupleManualAgent <: AbstractAgent
            id::Int
            pos::NTuple{2,Float64}
            vel::NTuple{2,Float64}
        end
        space = ContinuousSpace((1,1))
        @test_logs (
            :warn,
            "Using `NTuple` for the `pos` field of agent types in `ContinuousSpace` is deprecated. Use `SVector` instead."
        ) (
            :warn,
            "`vel` field in agent type should be of type `SVector{<:AbstractFloat}` when using ContinuousSpace."
        ) ABM(TupleManualAgent, space)
        model = ABM(TupleManualAgent, space; warn=false)
        x = (0.0, 0.0)
        v = (0.1, 0.0)
        dt = 1.0
        add_agent!(x, model, v)
        @test model[1].pos == x
        @test model[1].vel == v
        move_agent!(model[1], model, dt)
        @test model[1].pos == x .+ v.*dt
        model = ABM(TupleManualAgent, space; warn=false)
        add_agent!(model, v)
        @test model[1].pos isa NTuple && model[1].vel == v
        y = (0.5, 0.2)
        move_agent!(model[1], y, model)
        @test model[1].pos == y
        walk!(model[1], model[1].vel, model)
        @test model[1].pos == y .+ model[1].vel

        ## random walks
        ≃(x,y) = isapprox(x, y; atol = 1e-12) # \simeq
        space = ContinuousSpace((10,10), periodic=true)
        model = ABM(TupleManualAgent, space; warn=false)
        x₀ = (5.0, 5.0)
        v₀ = (1.0, 0.0)
        add_agent!(x₀, model, v₀)
        r = 2.0
        randomwalk!(model[1], model, r)
        # distance between initial and new position should be r
        @test norm(model[1].pos .- x₀) ≃ r
        # velocity module remains equal to previous r
        randomwalk!(model[1], model)
        @test norm(model[1].vel) ≃ r
        # verify that reorientations obey the specified angles
        space = ContinuousSpace((10,10), periodic=true)
        model = ABM(TupleManualAgent, space; warn=false)
        x₀ = (5.0, 5.0)
        v₀ = (1.0, 0.0)
        add_agent!(x₀, model, v₀)
        r = 1.0
        polar = [π/2] # degenerate distribution, only π/2 reorientations
        v₁ = (0.0, 1.0) # π/2
        x₁ = x₀ .+ v₁
        randomwalk!(model[1], model, r; polar)
        @test all(model[1].vel .≃ v₁)
        @test all(model[1].pos .≃ x₁)

        # verify boundary conditions are respected
        space1 = ContinuousSpace((2,2), periodic=true)
        space2 = ContinuousSpace((2,2), periodic=false)
        model1 = ABM(TupleManualAgent, space1; warn=false)
        model2 = ABM(TupleManualAgent, space2; warn=false)
        x₀ = (1.0, 1.0)
        v₀ = (1.0, 0.0)
        add_agent!(x₀, model1, v₀)
        add_agent!(x₀, model2, v₀)
        r = 1.1
        polar = [0.0] # no reorientation, move straight
        randomwalk!(model1[1], model1, r; polar)
        randomwalk!(model2[1], model2, r; polar)
        @test model1[1].pos[1] ≈ 0.1
        @test model2[1].pos[1] ≈ 2.0
        @test norm(model1[1].vel) == 1.1

        ## pathfinding
        using Agents.Pathfinding
        gspace = GridSpace((5, 5))
        cspace = ContinuousSpace((5., 5.))
        atol = 0.0001 
        pathfinder = AStar(cspace; walkmap = trues(10, 10))
        model = ABM(TupleManualAgent, cspace; properties = (pf = pathfinder,), warn = false)
        a = add_agent!((0., 0.), model, (0., 0.))
        @test is_stationary(a, model.pf)

        plan_route!(a, (4., 4.), model.pf)
        @test !is_stationary(a, model.pf)
        @test length(model.pf.agent_paths) == 1
        move_along_route!(a, model, model.pf, 0.35355)
        @test all(isapprox.(a.pos, (4.75, 4.75); atol))

        # test waypoint skipping
        move_agent!(a, (0.25, 0.25), model)
        plan_route!(a, (0.75, 1.25), model.pf)
        move_along_route!(a, model, model.pf, 0.807106)
        @test all(isapprox.(a.pos, (0.75, 0.849999); atol)) || all(isapprox.(a.pos, (0.467156, 0.967156); atol))
        # make sure it doesn't overshoot the end
        move_along_route!(a, model, model.pf, 20.)
        @test all(isapprox.(a.pos, (0.75, 1.25); atol))
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
            remove_all!(model)
            # we can parallelize these cell center coordinates with the coordinates
            # in the documentation figure showing the different GridSpace metric types.
            cell_centers = [SVector(0.05 + 0.1i, 0.05 + 0.1j) for i in 0:9, j in 0:9]
            for c in cell_centers
                add_agent!(c, model, SVector(0.0, 0.0), 0.01)
            end
            center = SVector(0.45, 0.45)
            center_id = 25
            rs = SVector(1, 2, 3.4) .* 0.1 .+ 0.001 # multiply with spacing and add ε for accuracy
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
            remove_all!(model)
            # Note that these two should NOT be in the same cell
            r0 = 0.01
            r1 = 0.08
            a = add_agent!(SVector(0.51, 0.51), model, (0.0, 0.0), 0.01)
            b = add_agent!(SVector(0.51 + r1, 0.51), model, (0.0, 0.0), 0.01)
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
            pos = SVector.([
                (7.074386436066224, 4.963014649338054)
                (5.831962448496828, 4.926297135685473)
                (5.122087781793935, 5.300031210394806)
                (3.9715633336430156, 4.8106570045816675)
            ])
            for i in 1:4
                add_agent_pos!(SpeedyContinuousAgent(i+2, pos[i], SVector(0.0, 0.0), 0), model)
            end
            pairs = interacting_pairs(model, 2.0, :all).pairs
            @test length(pairs) == 5
            @test (3, 6) ∉ pairs

            space2 = ContinuousSpace((10, 10); spacing = 0.1, periodic = false)
            model2 = ABM(SpeedyContinuousAgent, space2; scheduler = Schedulers.ByID())
            for i in 1:4
                add_agent_pos!(SpeedyContinuousAgent(i, pos[i], SVector(0.0, 0.0), 0), model2)
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
                pos::SVector{2,Float64}
                vel::SVector{2,Float64}
            end
            mutable struct AgentU2 <: AbstractAgent
                id::Int
                pos::SVector{2,Float64}
                vel::SVector{2,Float64}
            end
            function ignore_normal(model::ABM)
                [a.id for a in allagents(model) if !(typeof(a) <: SpeedyContinuousAgent)]
            end
            space3 = ContinuousSpace((10,10); spacing = 1.0, periodic = false)
            model3 = ABM(Union{SpeedyContinuousAgent, AgentU1, AgentU2}, space3; warn = false)
            for i in 1:10
                add_agent_pos!(SpeedyContinuousAgent(i, SVector(i/10, i/10), SVector(0.0, 0.0), 0), model3)
            end
            for i in 11:20
                add_agent_pos!(AgentU1(i, SVector(i/10-1, 0.5), SVector(0.0, 0.0)), model3)
            end
            for i in 21:30
                add_agent_pos!(AgentU2(i, SVector(0.45, i/10-2), SVector(0.0, 0.0)), model3)
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
            pos = SVector.([(0.01, 0.01),(0.2,0.2),(0.5,0.5)])
            for i in pos
            add_agent!(i,model,SVector(0.0,0.0),1.0)
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
            pos::SVector{2,Float64}
            vel::SVector{2,Float64}
            f1::Union{Int,Nothing}
        end
        space = ContinuousSpace((1,1); spacing = 0.1, periodic = true)
        model = ABM(AgentNNContinuous, space)
        pos = SVector.([(0.01, 0.01),(0.2, 0.01),(0.2, 0.2),(0.5, 0.5)])
        for i in pos
            add_agent!(i,model,SVector(0.0,0.0),nothing)
        end

        for agent in allagents(model)
            agent.f1 = nearest_neighbor(agent, model, sqrt(2)).id
        end

        @test model[1].f1 == 2
        @test model[2].f1 == 1
        @test model[3].f1 == 2
        @test model[4].f1 == 3
    end

    @testset "walk" begin
        # ContinuousSpace
        model = ABM(SpeedyContinuousAgent, ContinuousSpace((12, 10); periodic = false))
        a = add_agent!(SVector(0.0, 0.0), model, (0.0, 0.0), rand(abmrng(model)))
        walk!(a, SVector(1.0, 1.0), model)
        @test a.pos == SVector(1.0, 1.0)
        walk!(a, SVector(15.0, 1.0), model)
        @test a.pos == SVector(prevfloat(12.0), 2.0)

        @agent ContinuousAgent3D ContinuousAgent{3} begin end
        model = ABM(ContinuousAgent3D, ContinuousSpace((12, 10, 5); spacing = 0.2))
        a = add_agent!(SVector(0.0, 0.0, 0.0), model, SVector(0.0, 0.0, 0.0))
        walk!(a, SVector(1.0, 1.0, 1.0), model)
        @test a.pos == SVector(1.0, 1.0, 1.0)
        walk!(a, SVector(15.0, 1.2, 3.9), model)
        @test a.pos == SVector(4.0, 2.2, 4.9)

        # Must use Float64 for continuousspace
        @test_throws MethodError walk!(a, SVector(1, 1, 5), model)


        @testset "periodic" begin
            model = ABM(ContinuousAgent{2}, ContinuousSpace((12, 10); periodic = true))
            a = add_agent!(SVector(11.0, 9.0), model, SVector(3.0, 1.0))
            move_agent!(a, model, 1.0)
            @test a.pos[1] == 2
            @test a.pos[2] == 0.0
        end

    end

    @testset "collisions" begin
        speed = 0.002
        dt = 1.0
        diameter = 0.1
        @agent MassContinuousAgent ContinuousAgent{2} begin
            mass::Float64
        end

        function model_initiation()
            space = ContinuousSpace((10,10); periodic=true)
            model = ABM(MassContinuousAgent, space;
            rng=StableRNG(42), properties= Dict(:c => 0));
            # Add initial individuals
            for i in 1:10, j in 1:10
                    pos = SVector(i/10, j/10)
                if i > 5
                    vel = SVector(sincos(2π*rand(abmrng(model))) .* speed)
                    mass = 1.33
                else
                    # these agents have infinite mass and 0 velocity. They are fixed.
                    vel = SVector(0.0, 0.0)
                    mass = Inf
                end
                add_agent!(pos, model, vel, mass)
            end
            return model
        end

        agent_step!(agent, model) = move_agent!(agent, model, dt)
        function model_step!(model)
            ipairs = interacting_pairs(model, diameter, :nearest)
            for (a1, a2) in ipairs
                e = elastic_collision!(a1, a2, :mass)
                if e
                    abmproperties(model)[:c] += 1
                end
            end
        end

        function kinetic(model)
            # Kinetic enrgy
            K = sum(sum(abs2.(a.vel)) for a in allagents(model))
            # Momentum
            p = SVector(0.0, 0.0)
            for a in allagents(model)
                 p = p .+ a.vel
            end
            return K, p
        end

        model = model_initiation()
        initvels = [model[i].vel for i in 1:100]
        x = count(!isapprox(initvels[id][1], model[id].vel[1]) for id in 1:100)
        @test x == 0

        K0, p0 = kinetic(model)
        step!(model, agent_step!, model_step!, 10)
        ipairs = interacting_pairs(model, diameter, :nearest)
        @test length(ipairs) ≠ 100
        @test length(ipairs) ≠ 0

        step!(model, agent_step!, model_step!, 10)
        x = count(any(initvels[id] .≠ model[id].vel) for id in 1:100)
        y = count(!any(initvels[id] .≈ model[id].vel) for id in 1:50)
        @test y == 0

        # x, which is the changed velocities
        # should be at most half the agents
        # because half the agents are unmovable
        @test 0 < x ≤ 50
        @test model.c > 0
        K1, p1 = kinetic(model)
        @test p1 != p0
        # TODO: This test fails but I do not know why. Must be fixed later.
        # (Kinetic energy is not conserved)
        # @test K1 ≈ K0
    end

    @testset "random walk" begin
        ≃(x,y) = isapprox(x,y,atol=1e-12) # \simeq
        @testset "2D" begin
            space = ContinuousSpace((10,10), periodic=true)
            model = ABM(ContinuousAgent{2}, space)
            x₀ = SVector(5.0, 5.0)
            v₀ = SVector(1.0, 0.0)
            add_agent!(x₀, model, v₀)
            # should throw error if displacement is 0
            @test_throws ArgumentError randomwalk!(model[1], model, 0.0)
            r = 2.0
            randomwalk!(model[1], model, r)
            # distance between initial and new position
            # should be equal to r, independently of v₀
            @test norm(model[1].pos .- x₀) ≃ r
            @test !(norm(model[1].pos .- x₀) ≃ norm(v₀))

            # velocity module remains equal to previous r
            randomwalk!(model[1], model)
            @test norm(model[1].vel) ≃ r

            # verify that reorientations obey the specified angles
            space = ContinuousSpace((10,10), periodic=true)
            model = ABM(ContinuousAgent{2}, space)
            x₀ = SVector(5.0, 5.0)
            v₀ = SVector(1.0, 0.0)
            add_agent!(x₀, model, v₀)
            r = 1.0
            polar = [π/2] # degenerate distribution, only π/2 reorientations
            # at the 4th step, the agent should come back to its initial position
            v₁ = SVector(0.0, 1.0) # π/2
            x₁ = x₀ .+ v₁
            v₂ = SVector(-1.0, 0.0) # π
            x₂ = x₁ .+ v₂
            v₃ = SVector(0.0, -1.0) # 3π/2
            x₃ = x₂ .+ v₃
            randomwalk!(model[1], model, r; polar)
            @test all(model[1].vel .≃ v₁)
            @test all(model[1].pos .≃ x₁)
            randomwalk!(model[1], model, r; polar)
            @test all(model[1].vel .≃ v₂)
            @test all(model[1].pos .≃ x₂)
            randomwalk!(model[1], model, r; polar)
            @test all(model[1].vel .≃ v₃)
            @test all(model[1].pos .≃ x₃)
            randomwalk!(model[1], model, r; polar)
            @test all(model[1].vel .≃ v₀)
            @test all(model[1].pos .≃ x₀)

            # verify boundary conditions are respected
            space1 = ContinuousSpace((2,2), periodic=true)
            space2 = ContinuousSpace((2,2), periodic=false)
            model1 = ABM(ContinuousAgent{2}, space1)
            model2 = ABM(ContinuousAgent{2}, space2)
            x₀ = SVector(1.0, 1.0)
            v₀ = SVector(1.0, 0.0)
            add_agent!(x₀, model1, v₀)
            add_agent!(x₀, model2, v₀)
            r = 1.1
            polar = [0.0] # no reorientation, move straight
            randomwalk!(model1[1], model1, r; polar)
            randomwalk!(model2[1], model2, r; polar)
            @test model1[1].pos[1] ≈ 0.1
            @test model2[1].pos[1] ≈ 2.0
            @test norm(model1[1].vel) == 1.1
        end

        @testset "3D" begin
            space = ContinuousSpace((10,10,10), periodic=true)
            model = ABM(ContinuousAgent{3}, space)
            x₀ = SVector(5.0, 5.0, 5.0)
            v₀ = SVector(1.0, 0.0, 0.0)
            add_agent!(x₀, model, v₀)
            # should throw error if displacement is 0
            @test_throws ArgumentError randomwalk!(model[1], model, 0.0)
            r = 2.0
            randomwalk!(model[1], model, r)
            # distance between initial and new position
            # should be equal to Δr and independent of v₀
            @test norm(model[1].pos .- x₀) ≃ r
            @test !(norm(model[1].pos .- x₀) ≃ norm(v₀))

            # velocity module remains equal to previous r
            randomwalk!(model[1], model)
            @test norm(model[1].vel) ≃ r

            # verify that reorientations obey the specified angles
            space = ContinuousSpace((10,10,10), periodic=true)
            model = ABM(ContinuousAgent{3}, space)
            v₀ = SVector(1.0, 0.0, 0.0)
            add_agent!(model, v₀)
            r = 1.0
            θ = π/6
            polar = [θ]
            azimuthal = Arccos()
            randomwalk!(model[1], model, r; polar, azimuthal)
            # for any φ, dot(v₁,v₀) = cos(θ)
            v₁ = model[1].vel
            @test dot(v₁, v₀) ≃ cos(θ)

            space = ContinuousSpace((10,10,10), periodic=true)
            model = ABM(ContinuousAgent{3}, space)
            v₀ = SVector(1.0, 0.0, 0.0)
            add_agent!(model, v₀)
            r = 1.0
            θ = π/4
            φ = π/6
            polar = [θ]
            azimuthal = [φ]
            randomwalk!(model[1], model, r; polar, azimuthal)
            v₁ = model[1].vel
            @test v₁[1] ≃ cos(θ)
            @test v₁[2] ≃ sin(θ)*sin(φ)
            @test v₁[3] ≃ -sin(θ)*cos(φ)
            @test dot(v₁, v₀) ≃ cos(θ)

            # test that velocity measure changes
            space = ContinuousSpace((10,10,10), periodic=true)
            model = ABM(ContinuousAgent{3}, space)
            v₀ = SVector(1.0, 0.0, 0.0)
            add_agent!(model, v₀)
            randomwalk!(model[1], model, 2)
            @test norm(model[1].vel) ≈ 2
        end

        @testset "4D" begin
            space = ContinuousSpace((3,3,3,3), periodic=true)
            model = ABM(ContinuousAgent{4}, space)
            x₀ = SVector(2.0, 2.0, 2.0, 2.0)
            v₀ = SVector(0.2, 0.0, 0.0, 0.0)
            add_agent!(x₀, model, v₀)
            r = 0.5
            randomwalk!(model[1], model, r)
            # distance between initial and new position
            # should be equal to Δr and independent of v₀
            @test norm(model[1].pos .- x₀) ≃ r
            @test !(norm(model[1].pos .- x₀) ≃ norm(v₀))

            # velocity module remains equal to previous r
            randomwalk!(model[1], model)
            @test norm(model[1].vel) ≃ r
        end
    end
end

# Plotting for neighbors in continuous space
#=
using GLMakie
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
