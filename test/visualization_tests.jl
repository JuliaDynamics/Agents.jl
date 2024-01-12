
# TODO: write actual tests
@testset "agent visualizations" begin
	include("../examples/agents_visualizations.jl")
	# testing no error when removing files
	@test rm("daisyworld.mp4") === nothing
	include("../examples/zombies.jl")
	@test rm("outbreak.mp4") === nothing
end