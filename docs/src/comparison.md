# Agents.jl Performance and Complexity Comparison

Here we compare Agents.jl with three current and popular frameworks: Mesa, Netlogo and Mason, to assess where Agents.jl excels and also may need some future improvement.
We benchmark four models which showcase as many aspects of ABM simulation as possible.

- [Model of predator prey dynamics](@ref) (Wolf Sheep Grass), a [`GridSpace`](@ref) model, which requires agents to be added, removed and moved; as well as identify properties of neighbouring positions.
- The [Flock model](@ref) (Flocking), a [`ContinuousSpace`](@ref) model, chosen over other models to include a MASON benchmark. Agents must move in accordance with social rules over the space.
- The [Forest fire model](@ref) (Forest Fire), provides comparisons for cellular automata type ABMs (i.e. when agents do not move). NOTE: The Agents.jl implementation of this model has been changed in v4.0 to be directly comparable to Mesa and NetLogo. As a consequence it no longer follows the [original rule-set](https://en.wikipedia.org/wiki/Forest-fire_model).
- [Schelling's-segregation-model](@ref) (Schelling), an additional [`GridSpace`](@ref) model to compare with MASON. Simpler rules than Wolf Sheep Grass.

The results are characterised in two ways: how long it took each model to perform the same scenario (initial conditions, grid size, run length etc. are the same across all frameworks), and how many lines of code (LOC) it took to describe each model and its dynamics. We use this result as a metric to represent the complexity of learning and working with a framework.

Time taken is presented in normalised units, measured against the runtime of Agents.jl. In other words: the results do not depend on any computers specific hardware. If one wishes to repeat the results personally by using the scripts in `benchmark/compare/`, they will compute the same results. For details on the parameters used for each comparison, see the `benchmark/compare/benchmark.jl` file in our GitHub repository.

For LOC, we use the following convention: code is formatted using standard practices & linting for the associated language. Documentation strings and in-line comments (residing on lines of their own) are discarded, as well as any benchmark infrastructure. NetLogo is assigned two values since its files have a code base section and an encoding of the GUI. Since many parameters live in the GUI, we must take this into account. Thus `375 (785)` in a NetLogo count means 375 lines in the code section, 785 lines total in the file.

| Model/Framework | Agents | Mesa | Netlogo | MASON |
|---|---|---|---|---|
|Wolf Sheep Grass|1|7.1x|2.1x|NA|
|(LOC)|139|273|137 (871)| . |
|Flocking|1|29.7x|10.3xᕯ|2.1x|
|(LOC)|66|120|82 (689)|369|
|Forest Fire|1|29.1x|4.1x|NA|
|(LOC)|27|61|43 (545)|.|
|Schelling|1|31.5x|8.0x|14.3x|
|(LOC)|34|63|68 (732)|248|

ᕯ Netlogo has a different implementation to the other three frameworks here. It cheats a little by only choosing one nearest neighbor in some cases rather than considering all neighbors within vision. So a true comparison would ultimately see a slower result.

The results clearly speak for themselves. Across all four models, Agents.jl's performance is exceptional whilst using the least amount of code. This removes many frustrating barriers-to-entry for new users, and streamlines the development process for established ones.
