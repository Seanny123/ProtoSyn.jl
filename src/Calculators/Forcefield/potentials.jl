
struct CoulombLennardJonesPotential{K, N, T<:AbstractFloat} <: AbstractPotential
    key::KeyType{K,N}
    z::Int
    m::T
    q::T
    σ::T
    ϵ::T
end

struct HarmonicPotential{K, N, T<:AbstractFloat} <: AbstractPotential
    key::KeyType{K,N}
    x0::T
    kf::T
end

struct CosinePotential{K, N, T<:AbstractFloat} <: AbstractPotential
    key::KeyType{K,N}
    θ::T
    k::T
    n::T
end

struct NCosinePotential{K, N, T<:AbstractFloat} <: AbstractPotential
    key::KeyType{K,N}
    θ::Tuple{Vararg{T}}
    k::Tuple{Vararg{T}}
    n::Tuple{Vararg{T}}
end
NCosinePotential{K, N, T}(key::KeyType{K,N}, θ::Number, k::Number, n::Number) where {K,N,T<:AbstractFloat} = begin
    NCosinePotential{K, N, T}(key, (θ,), (k,), (n,))
end

const CoulombLennardJones{K,T} = CoulombLennardJonesPotential{K,1,T} where {K,T}
const    HarmonicBond{K,T} = HarmonicPotential{K,2,T} where {K,T}
const   HarmonicAngle{K,T} = HarmonicPotential{K,3,T} where {K,T}
const  CosineDihedral{K,T} =   CosinePotential{K,4,T} where {K,T}
const NCosineDihedral{K,T} =  NCosinePotential{K,4,T} where {K,T}

concrete(x::CoulombLennardJonesPotential{K,N,T}, k::KeyType{W,N}, q::T) where {K,N,T,W}= begin
    CoulombLennardJonesPotential{W,N,T}(k, x.z, x.m, q, x.σ, x.ϵ)
end

concrete(x::HarmonicPotential{K,N,T}, k::KeyType{W,N}) where {K,N,T,W}= begin
    HarmonicPotential{W,N,T}(k, x.x0, x.kf)
end
concrete(x::CosinePotential{K,N,T}, k::KeyType{W,N}) where {K,N,T,W}= begin
    CosinePotential{W,N,T}(k, x.θ, x.k, x.n)
end
concrete(x::NCosinePotential{K,N,T}, k::KeyType{W,N}) where {K,N,T,W}= begin
    NCosinePotential{W,N,T}(k, x.θ, x.k, x.n)
end



Base.:+(p1::NCosinePotential{K,N,T}, p2::NCosinePotential{K,N,T}) where {K,N,T} = begin
    NCosinePotential{K,N,T}(p1.key, (p1.θ...,p2.θ...), (p1.k...,p2.k...), (p1.n...,p2.n...))
end