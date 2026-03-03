using Aqua, Agents, Test

@testset "Code quality" begin
    Aqua.test_all(Agents, persistent_tasks = false, unbound_args = false, stale_deps = false)
    @test Test.detect_ambiguities(Agents) == Tuple{Method, Method}[]
end
