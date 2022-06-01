using Agents, Random
using StatsBase: sample
using GLMakie
using Makie.FreeTypeAbstraction
using InteractiveDynamics

"#765db4" # JuliaDynamics color

# Input
sir_colors(a) = a.status == :S ? "#2b2b33" : (a.status == :I ? "#bf2642" : "#338c54")
fontname = "Moon2.0-Regular.otf"
logo_dims = (1200, 400)
x, y = logo_dims
font = FreeTypeAbstraction.FTFont(joinpath(@__DIR__, fontname))
font_matrix = transpose(zeros(UInt8, logo_dims...))

FreeTypeAbstraction.renderstring!(
    font_matrix,
    "Agents.jl",
    font,
    150,
    round(Int, y / 2) + 50,
    round(Int, x / 2),
    halign = :hcenter,

)

# Use this to test how the font looks like:
# heatmap(font_matrix; yflip=true, aspect_ratio=1)

include("logo_model_def.jl")
sir = sir_logo_initiation(; N = 400)
fig, ax = abmplot(sir;
agent_step! = sir_agent_step!, model_step! = sir_model_step!,
enable_inspection = false,
ac = sir_colors, as = 6, figure = (resolution = logo_dims, ))
hidedecorations!(ax)
display(fig)

# record(fig, "agents.gif", 1:1300; framerate=60) do i
#     animstep!(pos, colors)
# end