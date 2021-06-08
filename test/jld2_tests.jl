@testset "JLD2" begin
    @testset "No space" begin
        model, _ = Models.hk()
        AgentsIO.dump_to_jld2("test.jld2", model)
        other = AgentsIO.load_from_jld2("test.jld2")

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].old_opinion == other[i].old_opinion for i in allids(model))
        @test all(model[i].new_opinion == other[i].new_opinion for i in allids(model))
        @test all(model[i].previous_opinion == other[i].previous_opinion for i in allids(model))
        # properties
        @test model.ϵ == other.ϵ
        # model data
        @test model.scheduler == other.scheduler
        @test model.rng == other.rng
        @test model.maxid.x == other.maxid.x

        rm("test.jld2")
    end

    @testset "GridSpace" begin
        # predator_prey used since properties is a NamedTuple, and contains an Array
        model, astep, mstep = Models.predator_prey()
        step!(model, astep, mstep, 50)
        AgentsIO.dump_to_jld2("test.jld2", model)
        other = AgentsIO.load_from_jld2("test.jld2"; scheduler = Schedulers.by_property(:type))
        
        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].type == other[i].type for i in allids(model))
        @test all(model[i].energy == other[i].energy for i in allids(model))
        @test all(model[i].reproduction_prob == other[i].reproduction_prob for i in allids(model))
        @test all(model[i].Δenergy == other[i].Δenergy for i in allids(model))
        # properties
        @test model.fully_grown == other.fully_grown
        @test model.countdown == other.countdown
        @test model.regrowth_time == other.regrowth_time
        # model data
        @test model.scheduler == other.scheduler
        @test model.rng == other.rng
        @test model.maxid.x == other.maxid.x
        # space data
        @test typeof(model.space) == typeof(other.space)    # to check periodicity
        @test size(model.space.s) == size(other.space.s)
        @test model.space.s == other.space.s
        @test model.space.metric == other.space.metric
        @test length(model.space.hoods) == length(other.space.hoods)
        @test all(other.space.hoods[k].whole == model.space.hoods[k].whole for (k, v) in model.space.hoods)
        @test all(other.space.hoods[k].βs == model.space.hoods[k].βs for (k, v) in model.space.hoods)
        @test all(other.space.hoods[k] == v for (k, v) in model.space.hoods)
        @test length(model.space.hoods_tuple) == length(other.space.hoods_tuple)
        @test all(haskey(other.space.hoods_tuple, k) for k in keys(model.space.hoods_tuple))
        @test all(other.space.hoods_tuple[k] == v for (k, v) in model.space.hoods_tuple)

        rm("test.jld2")
    end

    @testset "ContinuousSpace" begin
        model, astep, mstep = Models.social_distancing(N = 300)
        step!(model, astep, mstep, 100)
        AgentsIO.dump_to_jld2("test.jld2", model)
        other = AgentsIO.load_from_jld2("test.jld2")

        # agent data
        @test nagents(other) == nagents(model)
        @test all(haskey(other.agents, i) for i in allids(model))
        @test all(model[i].pos == other[i].pos for i in allids(model))
        @test all(model[i].vel == other[i].vel for i in allids(model))
        @test all(model[i].mass == other[i].mass for i in allids(model))
        @test all(model[i].days_infected == other[i].days_infected for i in allids(model))
        @test all(model[i].status == other[i].status for i in allids(model))
        @test all(model[i].β == other[i].β for i in allids(model))
        # properties
        @test model.infection_period == other.infection_period
        @test model.reinfection_probability == other.reinfection_probability
        @test model.detection_time == other.detection_time
        @test model.death_rate == other.death_rate
        @test model.interaction_radius == other.interaction_radius
        @test model.dt == other.dt
        # model data
        @test model.scheduler == other.scheduler
        @test model.rng == other.rng
        @test model.maxid.x == other.maxid.x
        # space data
        @test typeof(model.space) == typeof(other.space)    # to check periodicity
        @test size(model.space.grid.s) == size(other.space.grid.s)
        @test model.space.grid.s == other.space.grid.s
        @test model.space.grid.metric == other.space.grid.metric
        @test length(model.space.grid.hoods) == length(other.space.grid.hoods)
        @test all(haskey(other.space.grid.hoods, k) for k in keys(model.space.grid.hoods))
        @test all(other.space.grid.hoods[k].whole == model.space.grid.hoods[k].whole for (k, v) in model.space.grid.hoods)
        @test all(other.space.grid.hoods[k].βs == model.space.grid.hoods[k].βs for (k, v) in model.space.grid.hoods)
        @test length(model.space.grid.hoods_tuple) == length(other.space.grid.hoods_tuple)
        @test all(haskey(other.space.grid.hoods_tuple, k) for k in keys(model.space.grid.hoods_tuple))
        @test all(other.space.grid.hoods_tuple[k] == v for (k, v) in model.space.grid.hoods_tuple)
        @test model.space.update_vel! == other.space.update_vel!
        @test model.space.dims == other.space.dims
        @test model.space.spacing == other.space.spacing
        @test model.space.extent == other.space.extent

        rm("test.jld2")
    end
end