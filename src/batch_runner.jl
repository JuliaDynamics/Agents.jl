"""
    batchrunner(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Int64}, replicates::Integer)

Runs `replicates` number of simulation replicates and returns a `DataFrame`.
"""
function batchrunner(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Int64}, replicates::Integer)
  dataall = step!(agent_step, model_step, model, nsteps, properties, aggregators, steps_to_collect_data)
  for i in 2:replicates
    data = step!(agent_step, model_step, model, nsteps, properties, aggregators, steps_to_collect_data)
    dataall = join(dataall, data, on=:step, kind=:outer, makeunique=true)
  end
  return dataall
end

"""
    batchrunner(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, replicates::Integer)

Runs `replicates` number of simulation replicates and returns a `DataFrame`.
"""
function batchrunner(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, replicates::Integer)
  dataall = step!(agent_step, model_step, model, nsteps, properties, steps_to_collect_data)
  for i in 2:replicates
    data = step!(agent_step, model_step, model, nsteps, properties, steps_to_collect_data)
    dataall = join(dataall, data, on=:id, kind=:outer, makeunique=true)
  end
  return dataall
end

"""
    batchrunner(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Int64}, replicates::Integer)

Runs `replicates` number of simulation replicates and returns a `DataFrame`.
"""
function batchrunner(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Int64}, replicates::Integer)
  dataall = step!(agent_step, model, nsteps, properties, aggregators, steps_to_collect_data)
  for i in 2:replicates
    data = step!(agent_step, model, nsteps, properties, aggregators, steps_to_collect_data)
    dataall = join(dataall, data, on=:step, kind=:outer, makeunique=true)
  end
  return dataall
end

"""
    batchrunner(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, replicates::Integer)

Runs `replicates` number of simulation replicates and returns a `DataFrame`.
"""
function batchrunner(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, replicates::Integer)
  dataall = step!(agent_step, model, nsteps, properties, steps_to_collect_data)
  for i in 2:replicates
    data = step!(agent_step, model, nsteps, properties, steps_to_collect_data)
    dataall = join(dataall, data, on=:id, kind=:outer, makeunique=true)
  end
  return dataall
end