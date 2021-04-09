export TrueSelection
# Note: TrueSelection is a LEAF selection.

"""
    TrueSelection{T}()

A [`TrueSelection`](@ref) returns a [`Mask`](@ref) (of type
`T <: AbstractContainer`) with all entries set to `true`.

# State mode
    
The state mode of [`TrueSelection`] `M` is forced to be `Stateless`.

# Selection type

The selection type of [`RandomRangeSelection`](@ref) can be any
`T <: AbstractContainer`.

!!! ukw "Note:"
    This selection does not have a short syntax version.

# Examples
```jldoctest
julia> sele = TrueSelection{Atom}()
TrueSelection{ProtoSyn.Stateless,Atom}(true)
```
"""
mutable struct TrueSelection{M, T} <: AbstractSelection
    TrueSelection{T}() where {T <: AbstractContainer} = begin
        new{Stateless, T}()
    end
end

state_mode_type(::TrueSelection{M, T}) where {M, T} = M
selection_type(::TrueSelection{M, T})  where {M, T} = T


# --- Select -------------------------------------------------------------------
select(::TrueSelection{Stateless, T}, container::AbstractContainer) where {T <: AbstractContainer} = Mask{T}(trues(counter(T)(container)))