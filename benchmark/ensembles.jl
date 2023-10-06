@everywhere begin
    using Agents
    using Agents.Models: schelling, schelling_agent_step!, SchellingAgent
    using BenchmarkTools
end

ENSEMBLES_SUITE = BenchmarkGroup(["Ensembles"])

function ensemble_benchmark(f, parallel, nreplicates)
    # Set up basic parameters: number of replicates, numagents_low, etc.
    nsteps = 2000
    numagents_low = 200
    numagents_high = 300

    whensteps = 50

    function genmodels(nreplicates)
        basemodels = [Models.schelling(; numagents)[1]
                      for numagents in collect(numagents_low:numagents_high)]

        return repeat(basemodels, nreplicates)
    end

    if f == ensemblerun!
        models = genmodels(nreplicates)
        adf, mdf, _ = ensemblerun!(models, schelling_agent_step!, dummystep, nsteps;
                                   parallel, adata = [:pos, :mood, :group],
                                   showprogress = true,
                                   when = (model, step) ->
                                    ( (step) % whensteps == 0  ||  step == 0 ),
                                   mdata = [:min_to_be_happy])
    else
        # TODO: Why do we need `replicate_idx` here?
        # Can't we just use the `Models.schelling`?
        function initialize(;
            replicate_idx = 1, numagents = 320, griddims = (20, 20), min_to_be_happy = 3
        )
            space = GridSpace(griddims, periodic = false)
            properties = Dict(:min_to_be_happy => min_to_be_happy)

            model = StandardABM(SchellingAgent, space;
                        properties = properties, scheduler = Schedulers.randomly)

            for n in 1:numagents
                add_agent_single!(SchellingAgent, model, false, n < numagents / 2 ? 1 : 2)
            end

            return model
        end

        parameters = Dict(
            :numagents => collect(numagents_low:numagents_high),
            :replicate_idx => collect(1:nreplicates),
            :griddims => (20, 20),
        )
        paramscan(parameters, initialize;
                  parallel, adata = [:pos, :mood, :group],
                  mdata = [:min_to_be_happy], showprogress = true,
                  agent_step! = schelling_agent_step!,
                  when = (model, step) ->
                   ( (step) % whensteps == 0  ||  step == 0 ),
                  n = nsteps)
    end
end

for (f, parallel, nreplicates, name) in [
    (ensemblerun!, false, 10, "ensemblerun! serial 10 reps"),
    (ensemblerun!, true, 10, "ensemblerun! parallel 10 reps"),
    (ensemblerun!, false, 20, "ensemblerun! serial 20 reps"),
    (ensemblerun!, true, 20, "ensemblerun! parallel 20 reps"),
    (paramscan, false, 10, "paramscan serial 10 reps"),
    (paramscan, true, 10, "paramscan parallel 10 reps"),
    (paramscan, false, 20, "paramscan serial 20 reps"),
    (paramscan, true, 20, "paramscan parallel 20 reps")
]
    ENSEMBLES_SUITE[name] = @benchmarkable ensemble_benchmark($f, $parallel, $nreplicates) samples = 1
end
