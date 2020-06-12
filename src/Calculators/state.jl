struct State{T<:AbstractFloat}
    size::Int
    x::Matrix{T}
    f::Matrix{T}
    # e::Dict{DataType,T}
    e::Dict{Symbol,T}
end

State{T}(n::Int) where T = State{T}(n, zeros(T,n,3), zeros(T,n,3), Dict())

State(src::ProtoSyn.State{T}) where T = begin
    state = State{T}(src.size)
    copy!(state, src)
end

State(src::State{T}) where T = begin
    state = State{T}(src.size)
    copy!(state, src)
end



Base.copy!(dst::ProtoSyn.State{T}, src::State{T}) where T = begin
    x = src.x
    @inbounds for i=1:src.size
        t = dst[i].t
        t[1] = x[i,1]
        t[2] = x[i,2]
        t[3] = x[i,3]
    end
    ProtoSyn.request_c2i(dst; all=true)
end



Base.copy!(dst::State{T}, src::ProtoSyn.State{T}) where T = begin
    x = dst.x
    @inbounds for i=1:dst.size
        t = src[i].t
        x[i,1] = t[1]
        x[i,2] = t[2]
        x[i,3] = t[3]
    end
    dst
end



Base.copy!(dst::State{T}, src::State{T}) where T = begin
    copy!(dst.x, src.x)
    copy!(dst.f, src.f)
    copy!(dst.e, src.e)
    dst
end


Base.reset(s::State{T}) where T = begin
    e = s.e
    for k in keys(e); e[k] = 0; end
    fill!(s.f, 0)
    s
end

export energy
energy(s::State) = sum(values(s.e))
setenergy!(s::State, key::Symbol, value) = (s.e[key]=value; s)
#setenergy!(s::State, base::Symbol, suffix::Symbol, value) = (s.e[key]=value; s)


@inline coordinates(s::State) = s.x
@inline forces(s::State) = s.f

function atmax(state::Calculators.State{T}, comp::Symbol) where T
    m = T(0)
    idx = 0
    x = getproperty(state, comp)
    for i = 1:state.size
        f = x[i,1]^2 + x[i,2]^2 + x[i,3]^2
        if f > m
            m = f
            idx = i
        end
    end
    return sqrt(m),idx
end