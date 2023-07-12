using PrecompileTools

@setup_workload begin
    @compile_workload begin
        model, agent_step!, model_step! = Models.flocking()
        step!(model, agent_step!, model_step!, 1)
        model, agent_step!, model_step! = Models.schelling()
        step!(model, agent_step!, model_step!, 1)
        model, agent_step!, model_step! = Models.zombies()
        step!(model, agent_step!, model_step!, 1)
        model, agent_step!, model_step! = Models.sir()
        step!(model, agent_step!, model_step!, 1)
    end
end