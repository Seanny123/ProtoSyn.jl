module ILSRR

using ..Aux
using ..Common
using ..Drivers
using Printf


@doc raw"""
    Driver(inner_cycle_driver!::Drivers.AbstractDriver, evaluator!::Function, pertubator!::Function[, temperature::Float64 = 0.0, n_steps::Int64 = 0, callbacks::Tuple{Common.CallbackObject}...])

Define the runtime parameters for the ILSRR algorithm.

# Arguments
- `inner_cycle_driver!::Driver.AbstractDriver`: Responsible for driving the inner cycle of the ILSRR algorithm. Should be a Driver, such as [`MonteCarlo`](@ref Drivers)
- `evaluator!::Function`: Responsible for evaluating the current `state.energy`. This function should have the following signature:
```
evaluator!(state::Common.State, do_forces::Bool)
```
- `pertubator!::Function`: Responsible for performing conformational changes in the system. It's usually an aggregation of [Mutators](@ref Mutators).
- `temperature::Float64`: (Optional) Temperature for the Metropolis criteria when performing system perturbation (Default: 0.0).
- `n_steps`: (Optional) Total amount of outer cycles to be performed (Default: 0).
- `continue_after_n_attemps`: (Optional) If defined, will reset to initial structure after `continue_after_n_attemps` jumps who consecutively fail to produce a new optimum (Default: 0).
- `callbacks`: (Optional) Tuple of [`CallbackObject`](@ref Common)s.

# Examples
```julia-repl
julia> Drivers.ILSRR.Driver(inner_cycle_driver, my_evaluator!, my_pertubator)
ILSRR.Driver(evaluator=my_evaluator!, n_steps=100, f_tol=1e-3, max_step=0.1)

julia> Drivers.ILSRR.Driver(inner_cycle_driver, my_evaluator!, my_pertubator, 300.0, 10)
ILSRR.Driver(evaluator=my_evaluator!, temperature=300.0, n_steps=10)
```
!!! tip
    The `my_evaluator!` function often contains an aggregation of pre-defined functions avaliable in [Forcefield](@ref Forcefield). It is possible to combine such functions using the [`@faggregator`](@ref Common) macro.

See also: [`run!`](@ref)
"""
Base.@kwdef mutable struct DriverConfig{F <: Function, G <: Function, H <: Function}
    #TO DO: Documentation
    inner_driver!::F
    inner_driver_config::Union{Drivers.AbstractDriverConfig, Nothing}
    perturbator!::H
    anneal_fcn::G
    n_steps::Int = 0
end
function DriverConfig(inner_driver!::F, inner_driver_config::Drivers.AbstractDriverConfig, perturbator!::G, temperature::Float64 = 0.0) where {F <: Function, G <: Function}
    return DriverConfig(inner_driver! = inner_driver!, inner_driver_config = inner_driver_config, perturbator! = perturbator!, anneal_fcn = (n::Int64)->temperature)
end


#TO DO: Documentation
Base.@kwdef mutable struct DriverState <: Drivers.AbstractDriverState
    best_state::Union{Common.State, Nothing} = nothing
    home_state::Union{Common.State, Nothing} = nothing
    step::Int                                = 0
    n_stalls::Int                            = 0
    temperature::Float64                     = -1.0
    completed::Bool                          = false
    stalled::Bool                            = false
end


@doc raw"""
    run!(state::Common.State, driver::SteepestDescentDriver[, callback::Union{Common.CallbackObject, Nothing} = nothing])

Run the main body of the Driver.

# Arguments
- `state::Common.State`: Current state of the system to be modified.
- `driver::SteepestDescentDriver`: Defines the parameters for the ILSRR algorithm. See [`Driver`](@ref).
- `callbacks::Vararg{Common.CallbackObject, N}`: (Optional) Tuple of [`CallbackObject`](@ref Common)s.

!!! tip
    The callback function often contains a [Print](@ref) function.

# Examples
```julia-repl
julia> Drivers.ILSRR.run(state, ilsrr_driver, callback1, callback2, callback3)
```
"""
function run!(state::Common.State, driver_config::DriverConfig, callbacks::Common.CallbackObject...)

    driver_state = DriverState()
    
    inner_driver! = driver_config.inner_driver
    inner_driver_config = driver_config.inner_driver_config
    
    let n_steps=inner_driver_config.n_steps
        inner_driver_config.n_steps = 0
        inner_driver!(state, inner_driver_config)
        inner_driver_config.n_steps = n_steps
    end
    
    driver_state.best_state = Common.State(state)
    driver_state.home_state = Common.State(state)
    driver_state.completed = driver_state.step == driver_config.n_steps

    @Common.cbcall callbacks state driver_state driver_config
    
    R = 0.0083144598 # kJ mol-1 K-1

    #region MAINLOOP
    while !(driver_state.completed || driver_state.stalled)
        
        # this driver should make multiple small tweaks
        # to the state
        inner_driver!(state, inner_driver_config, callbacks)
        
        driver_state.step += 1
        driver_state.temperature = driver_config.anneal_fcn(driver_state.step)
        
        if state.energy.total < driver_state.best_state.energy.total
            # save this state as the best and make
            # it the new homebase
            @Common.copy driver_state.best_state state energy xyz
            @Common.copy driver_state.home_state state energy xyz
            n_stalls = 0
        else
            # otherwise, a new homebase may be created according
            # to the Metropolis criterium
            β = driver_state.temperature != 0.0 ? 1/(R * driver_state.temperature) : Inf
            ΔE = state.energy.total - driver_state.home_state.energy.total
            if (ΔE <= 0.0) || (rand() < exp(-ΔE*β) )
                @Common.copy driver_state.home_state state energy xyz
                n_stalls = 0
            else
                # if the criterium was not accepted, revert
                # to the homebase
                @Common.copy state driver_state.home_state energy xyz
                n_stalls += 1
            end
        end
        
        driver_state.stalled = n_stalls == driver_config.stall_limit
        driver_state.completed = driver_state.step == driver_config.n_steps
        
        # make a large perturbation to the state
        if !(driver_state.completed || driver_state.stalled)
            driver_config.perturbator!(state)
        end

        @Common.cbcall callbacks state driver_state driver_config
    end
    #endregion

    # before returning, save the best state
    if driver_state.best_state.energy.total < state.energy.total
        @Common.copy state driver_state.best_state energy xyz
    end

    return driver_state
end # end function

end # end module