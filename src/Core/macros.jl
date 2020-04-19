using Base.Cartesian

@doc """
> @macroexpand @dot u a_u b_u
:(a_1 * b_1 + a_2 * b_2 + a_3 * b_3)
"""
macro dot(s::Symbol, v1::Symbol, v2::Symbol)
    esc(:(@ncall(3,+,$s -> $v1*$v2)))
end



#macro d(p::Symbol, n::Int)
#    s = Symbol(p, "_", (n-1)%3+1)
#    esc(:($s))
#end

cycle(n::Int) = (n-1)%3+1


@doc """
> @macroexpand @cross u out_u a_u b_u
quote
    out_1 = a_2 * b_3 - a_3 * b_2
    out_2 = a_3 * b_1 - a_1 * b_3
    out_3 = a_1 * b_2 - a_2 * b_1
end
"""
macro cross(s::Symbol, v::Union{Symbol, Expr}, v1::Union{Symbol, Expr}, v2::Union{Symbol, Expr})
    v  = :($s -> $v)
    v1 = :($s -> $v1)
    v2 = :($s -> $v2)
    aexprs = Any[
        Expr(
            :escape,
            Expr(
                :(=),
                Base.Cartesian.inlineanonymous(v, i),
                Expr(
                    :call,
                    :(-),
                    Expr(
                        :call,
                        :(*),
                        Base.Cartesian.inlineanonymous(v1, cycle(i+1)),
                        Base.Cartesian.inlineanonymous(v2, cycle(i+2))
                    ),
                    Expr(
                        :call,
                        :(*),
                        Base.Cartesian.inlineanonymous(v1, cycle(i+2)),
                        Base.Cartesian.inlineanonymous(v2, cycle(i+1))
                    )
                )
            )
        )
        for i = 1:3
    ]
    Expr(:block, aexprs...)
end

#@show @macroexpand  @nexprs(3, u -> $out = @d(v12,u+1)*@d(v32,u+2) - @d(v12,u+2)*@d(v32,u+1))
#@show @macroexpand @nexprs 3 u -> vm_u = @d(v12,u+1)*@d(v32,u+2) - @d(v12,u+2)*@d(v32,u+1)
# f = @macroexpand @cross u out_u a_u b_u
#dump(:(a=11+2))
#dump(f)
# @show f




macro fieldcopy!(dst::Symbol, src::Symbol, components::QuoteNode...)
    ex = quote end
    for comp in components
        push!(ex.args, :(copy!(getproperty($(dst), $(comp)), getproperty($(src), $(comp)))))
    end
    esc(ex)
end

# using .XMLRPC

# macro pymol(ex, objname=nothing)
#     @assert isdefined(Main, :proxy) "a pymol proxy must be defined"
#     @assert Main.proxy isa XMLRPC.ServerProxy "proxy must be of type ProtoSyn.XMLRPC.ServerProxy"

#     return quote
#         local val = $(esc(ex))
#         if val isa ProtoSyn.State
#             Main.proxy.load_coordset(val.coords, $(esc(objname)), 0)
#             # Main.proxy.set_title($(esc(objname)), -1, $(string(ex)))
#         elseif val isa Tuple{Molecule,State}
#             io = IOBuffer()
#             write(io, val[1], val[2], PDB)
#             Main.proxy.read_pdbstr(String(take!(io)), $(esc(objname)) !== nothing || val[1].name)
#             close(io)
#         end
#         val
#     end
# end