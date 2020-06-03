using Base.Cartesian
import ..Calculators.eval!

@generated function eval!(state::State{T}, ff::Forcefield2, ::Type{Val{DoF}}) where {T<:AbstractFloat, DoF}
quote
    reset(state)
    for (k,v) in ff.components
        eval!(state, v, Val{DoF})
    end
    state
end
end



@generated function eval!(state::State{T}, bonds::Vector{HarmonicBond{Int,T}}, ::Type{Val{DoF}}) where {T<:AbstractFloat, DoF}
println("generating for $DoF, $T")
quote
    energy = $(T(0))
    coords = state.x
    forces = state.f
    @inbounds for bond in bonds
        a1 = bond.key[1]
        a2 = bond.key[2]
        
        @nexprs 3 u -> v12_u = coords[a2,u] - coords[a1,u]
        d12 = sqrt(@dot(u, v12_u, v12_u))
        dr = d12 - bond.x0

        energy += bond.kf * dr * dr

        #region FORCE_SECTION
        $(if DoF === true
            quote
                fc = bond.kf * dr / d12
                @nexprs 3 u -> forces[a1, u] += fc * v12_u
                @nexprs 3 u -> forces[a2, u] -= fc * v12_u
            end
        end)
        #endregion

    end
    state.e[HarmonicBond{Int,T}] = energy/2
    state
end
end




@generated function eval!(state::State{T}, angles::Vector{HarmonicAngle{Int,T}}, ::Type{Val{DoF}}) where {T<:AbstractFloat, DoF}
quote
    energy = $(T(0))
    coords = state.x
    forces = state.f
    
    @inbounds for angle in angles
        a1,a2,a3 = angle.key

        @nexprs 3 u -> v21_u = coords[a1,u] - coords[a2,u]
        @nexprs 3 u -> v23_u = coords[a3,u] - coords[a2,u]

        # 1.0/(v21⋅v21)
        inv_d21sq  = 1.0 / @dot(u, v21_u, v21_u)
        
        # 1.0/(v23⋅v23)
        inv_d23sq  = 1.0 / @dot(u, v23_u, v23_u)
        
        # cos(θ) = v21⋅v23/(|v21|*|v23|)
        ctheta = @dot(u, v21_u, v23_u)

        inv_d21xd23 = sqrt(inv_d21sq * inv_d23sq)
        ctheta *= inv_d21xd23
        
        dtheta  = acos(ctheta) - angle.x0
        energy += angle.kf * dtheta * dtheta
        
        #region FORCE_SECTION
        $(if DoF === true
            quote
                # prevent division by zero
                fc = max(1.0 - ctheta*ctheta, 1e-8)
                fc = dtheta * angle.kf / sqrt(fc)
                
                @nexprs 3 u -> begin
                    f1 = fc*(ctheta * v21_u*inv_d21sq - v23_u*inv_d21xd23)
                    f3 = fc*(ctheta * v23_u*inv_d23sq - v21_u*inv_d21xd23)
                    forces[a1, u] -= f1
                    forces[a2, u] += (f1 + f3)
                    forces[a3, u] -= f3
                end
            end
        end)
        #endregion
            
    end
    state.e[HarmonicAngle{Int,T}] = energy/2
    state
end
end





@generated function eval!(state::State{T}, dihedrals::Vector{CosineDihedral{Int,T}}, ::Type{Val{DoF}}) where {T<:AbstractFloat, DoF}
quote
    energy = $(T(0))
    coords = state.x
    forces = state.f
    @inbounds for dihd in dihedrals

        a1,a2,a3,a4 = dihd.key
        
        @nexprs 3 u -> v12_u = coords[a2,u] - coords[a1,u]
        @nexprs 3 u -> v32_u = coords[a2,u] - coords[a3,u]
        @nexprs 3 u -> v34_u = coords[a4,u] - coords[a3,u]
        
        d32sq = @dot u v32_u v32_u
        d32 = sqrt(d32sq)
        
        @cross u vm_u v12_u v32_u   # v12 × v32
        @cross u vn_u v32_u v34_u   # v32 × v34
        d12n = @dot u v12_u vn_u    # v12⋅vn
        dmn  = @dot u vm_u vn_u     # vm⋅vn

        phi = atan(d32 * d12n, dmn)
        energy += dihd.k * (1.0 + cos(dihd.n * phi - dihd.θ))
        
        #region FORCE_SECTION
        $(if DoF === true
            quote
                
                dVdphi_x_d32 = dihd.k * dihd.n * sin(dihd.θ - dihd.n * phi) * d32
                d3432 = @dot(u, v34_u, v32_u)   # v34⋅v32
                d1232 = @dot(u, v12_u, v32_u)   # v12⋅v32
                dmm = @dot(u, vm_u, vm_u)       # vm⋅vm
                dnn = @dot(u, vn_u, vn_u)       # vn⋅vn
                
                c3_1 = (d3432/d32sq - 1.0)
                c3_2 = (d1232/d32sq)

                c1   = -dVdphi_x_d32 / dmm
                c4   =  dVdphi_x_d32 / dnn

                @nexprs 3 u -> begin
                    f1 = vm_u * c1
                    f4 = vn_u * c4
                    f3 = f4 * c3_1 - f1 * c3_2
                    forces[a1, u] -= f1
                    forces[a2, u] -= (-f1 - f3 - f4)
                    forces[a3, u] -= f3
                    forces[a4, u] -= f4
                end
            end
        end)
        #endregion

    end
    state.e[CosineDihedral{Int,T}] = energy
    state
end
end



@generated function eval!(state::State{T}, dihedrals::Vector{NCosineDihedral{Int,T}}, ::Type{Val{DoF}}) where {T<:AbstractFloat, DoF}
    quote
        energy = $(T(0))
        coords = state.x
        forces = state.f
        @inbounds for dihd in dihedrals
    
            a1,a2,a3,a4 = dihd.key
            
            @nexprs 3 u -> v12_u = coords[a2,u] - coords[a1,u]
            @nexprs 3 u -> v32_u = coords[a2,u] - coords[a3,u]
            @nexprs 3 u -> v34_u = coords[a4,u] - coords[a3,u]
            
            d32sq = @dot u v32_u v32_u
            d32 = sqrt(d32sq)
            
            @cross u vm_u v12_u v32_u   # v12 × v32
            @cross u vn_u v32_u v34_u   # v32 × v34
            d12n = @dot u v12_u vn_u    # v12⋅vn
            dmn  = @dot u vm_u vn_u     # vm⋅vn
    
            phi = atan(d32 * d12n, dmn)
            for i in eachindex(dihd.k)
                energy += dihd.k[i] * (1.0 + cos(dihd.n[i] * phi - dihd.θ[i]))
            end
            
            #region FORCE_SECTION
            $(if DoF === true
                quote
                    
                    d3432 = @dot(u, v34_u, v32_u)   # v34⋅v32
                    d1232 = @dot(u, v12_u, v32_u)   # v12⋅v32
                    dmm = @dot(u, vm_u, vm_u)       # vm⋅vm
                    dnn = @dot(u, vn_u, vn_u)       # vn⋅vn
                    
                    c3_1 = (d3432/d32sq - 1.0)
                    c3_2 = (d1232/d32sq)
                    
                    for i in eachindex(dihd.k)
                        dVdphi_x_d32 = dihd.k[i] * dihd.n[i] * sin(dihd.θ[i] - dihd.n[i] * phi) * d32
                        c1   = -dVdphi_x_d32 / dmm
                        c4   =  dVdphi_x_d32 / dnn
        
                        @nexprs 3 u -> begin
                            f1 = vm_u * c1
                            f4 = vn_u * c4
                            f3 = f4 * c3_1 - f1 * c3_2
                            forces[a1, u] -= f1
                            forces[a2, u] -= (-f1 - f3 - f4)
                            forces[a3, u] -= f3
                            forces[a4, u] -= f4
                        end
                    end
                end
            end)
            #endregion
    
        end
        state.e[NCosineDihedral{Int,T}] = energy
        state
    end
    end