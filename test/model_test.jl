@testset "Model tests" begin
  mutable struct Dummy <: AbstractAgent
    id
    pos
  end
  @test ABM(Dummy) != false
end