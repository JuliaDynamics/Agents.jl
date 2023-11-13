using Aqua

@testset "Code quality" begin
	Aqua.test_all(Agents, ambiguities = false, unbound_args = false)
	@test Test.detect_ambiguities(Agents) == Tuple{Method, Method}[]
end
