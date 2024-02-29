
using PrecompileTools

@setup_workload begin
    @compile_workload begin
        expr = :(struct A(NoSpaceAgent)
				    a::Float64 = 3
				    const b::Float64
				    c::Int
				end)
        _agent(expr)
        expr = :(struct A(GridAgent{2})
				    a::Float64 = 3
				    const b::Float64
				    c::Complex
				end)
        _agent(expr)
        expr = :(struct A(ContinuousAgent{2, Float64})
				    a::Float64 = 3
				    const b::Float64
				    c::Bool
				end)
        _agent(expr)
        expr = :(struct A(GraphAgent)
				    a::Float64 = 3
				    const b::Float64
				    c::Int16
				end)
        _agent(expr)
		expr = :(struct A(NoSpaceAgent) <: AbstractA
				    @subagent struct B
				        x::Int
				    end
				    @subagent struct C
				        y::Int
				    end
				end)
		_multiagent(QuoteNode(:opt_memory), expr)
		_multiagent(QuoteNode(:opt_speed), expr)	
		expr = :(struct A{X}(GridAgent{2})
				    @subagent struct B
				        x::Bool = false
				        y::Int
				    end
				    @subagent struct C{X<:Real}
				        y::Int
				        z::X
				    end
				end)
		_multiagent(QuoteNode(:opt_memory), expr)
		_multiagent(QuoteNode(:opt_speed), expr)
    end
end
