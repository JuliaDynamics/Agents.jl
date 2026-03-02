using PrecompileTools

@setup_workload begin
    @compile_workload begin
        expr = :(
            struct A(NoSpaceAgent)
                a::Float64 = 3
                const b::Float64
                c::Int
            end
        )
        _agent(expr)
        expr = :(
            struct A(GridAgent{2})
                a::Float64 = 3
                const b::Float64
                c::Complex
            end
        )
        _agent(expr)
        expr = :(
            struct A(ContinuousAgent{2, Float64})
                a::Float64 = 3
                const b::Float64
                c::Bool
            end
        )
        _agent(expr)
        expr = :(
            struct A(GraphAgent)
                a::Float64 = 3
                const b::Float64
                c::Int16
            end
        )
        _agent(expr)
    end
end
