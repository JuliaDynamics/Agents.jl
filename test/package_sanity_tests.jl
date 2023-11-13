
@testset "Code quality" begin
    @test Test.detect_ambiguities(Agents) == Tuple{Method, Method}[]
end
