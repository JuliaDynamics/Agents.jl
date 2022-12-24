using Agents, Random
using StatsBase: sample
using GLMakie
using InteractiveDynamics

# Input

# Some nice colors:
pink_green = Dict(:S => "#2b2b33", :I => "#a533d6", :R => "#338c54")
pink_green_dark = Dict(:S => "#d068fc", :I => "#72cc94", :R => "#f0f0f0")
juliadynamics = Dict(:S => JULIADYNAMICS_COLORS[3],
                     :I => JULIADYNAMICS_COLORS[1],
                     :R => JULIADYNAMICS_COLORS[2])

backgroundcolor = "#1e1e20" # `"#1e1e20"` or `:white`

colors_used = pink_green_dark

BLACK = colors_used[:R]
sir_colors(a) = colors_used[a.status]
fontname = "Overlock-Regular.otf"
logo_dims = (1200, 400)
x, y = logo_dims
font = Makie.to_font(joinpath(@__DIR__, fontname))
font_matrix = transpose(zeros(UInt8, logo_dims...))

Makie.renderstring!(font_matrix,
                    "Agents.jl",
                    font,
                    round(Int, logo_dims[2] / 2),
                    round(Int, y / 2 + logo_dims[2] / 6),
                    round(Int, x / 2),
                    halign = :hcenter)

# Use this to test how the font looks like:
# fig, = heatmap(font_matrix; yflip=true, aspect_ratio=1)

# Need to finetune the agent size, the interaction radius,
# the figure size, and the speed of the agents for a smooth video

include("logo_model_def.jl")

static_preplot!(ax, model) = hidedecorations!(ax)
ax_kwargs = (;
             leftspinecolor = BLACK,
             rightspinecolor = BLACK,
             topspinecolor = BLACK,
             bottomspinecolor = BLACK,
             backgroundcolor
             # ax.leftspinevisible = false,
             # ax.rightspinevisible = false,
             # ax.topspinevisible = false,
             # ax.bottomspinevisible = false,
             )

# Test:
sir = sir_logo_initiation(; N = 400, interaction_radius = 0.035)
fig, ax = abmplot(sir;
                  # agent_step! = sir_agent_step!, model_step! = sir_model_step!,
                  enable_inspection = false,
                  ac = sir_colors, as = 9, static_preplot!,
                  figure = (resolution = logo_dims,), axis = ax_kwargs)
display(fig)

# %% actually make the video
using CairoMakie
CairoMakie.activate!()
sir = sir_logo_initiation(; N = 600, interaction_radius = 0.035)
abmvideo("agents4_logo.gif", sir, sir_agent_step!, sir_model_step!;
         ac = sir_colors, as = 9, static_preplot!,
         figure = (resolution = logo_dims, backgroundcolor),
         axis = ax_kwargs, showstep = false,
         # For gif:
         spf = 4, framerate = 30, frames = 450
         # For mp4:
         # spf = 2, framerate = 60, frames = 900,
         )

# %% Save final figure for making the icon
fig, ax = abmplot(sir;
                  enable_inspection = false,
                  ac = sir_colors, as = 9, static_preplot!,
                  figure = (resolution = logo_dims, backgroundcolor), axis = ax_kwargs)
CairoMakie.save("agents_for_icon.png", fig)
