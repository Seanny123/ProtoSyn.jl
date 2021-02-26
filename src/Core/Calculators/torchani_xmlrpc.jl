using LightXML

server = nothing

function calc_torchani_model_xmlrpc(::Union{Type{ProtoSyn.SISD_0}, Type{ProtoSyn.SIMD_1}}, pose::Pose; update_forces::Bool = false, model_index::Int = 3)
    println("ERROR: 'calc_torchani_model_xmlrpc' requires CUDA_2 acceleration.")
    return 0.0, nothing
end


"""
    start_torchANI_server()

If TorchANI.server is not `nothing`, start a new TorchANI XML-RPC server. Return
a XMLRPC.ClientProxy (used to send XML requests to the created server).

# See also:
`stop_torchANI_server`
"""
function start_torchANI_server()
    proxy = ProtoSyn.XMLRPC.ClientProxy(
        "http://localhost", ProtoSyn.Units.defaultTorchANIport)

    server !== nothing && begin
        @warn "TorchANI XML-RPC server is already online!"
        return proxy
    end

    server_file = joinpath(@__DIR__, "torchani_server.py")
    println("Starting TorchANI XML-RPC server ...")
    global server = nothing
    global server = run(`python $server_file`, wait = false)
    println("TorchANI XML-RPC server is online!")
    return proxy
end


"""
    stop_torchANI_server()

If TorchANI.server is not `nothing`, kill the current TorchANI XML-RPC server.

# See also:
`start_torchANI_server`
"""
function stop_torchANI_server()
    global server
    if server !== nothing
        kill(server)
        server = nothing
    else
        @warn "No online TorchANI XML-RPC server was found."
    end
end


"""
    r_xml_travel!(xml::Union{XMLDocument, XMLElement}, query::String, results::Vector{T}) where {T <: AbstractFloat}

Recursively travel the XMLDocument or XMLElement and gather all entrys of label
type `query`, pushing them to the `results` vector (a parse for the correct T
type is attempted).
"""
function r_xml_travel!(xml::Union{XMLDocument, XMLElement}, query::String, results::Vector{T}) where {T <: AbstractFloat}

    if typeof(xml) == XMLDocument
        xml = LightXML.root(xml)
    end
    for element in child_elements(xml)
        if name(element) == query
            value = string(collect(child_nodes(element))[1])
            push!(results, parse(T, value))
        end
        is_elementnode(element) && r_xml_travel!(element, query, results)
    end
end


"""
    Calculators.calc_torchani_model_xmlrpc([::A], pose::Pose; update_forces::Bool = false, model::Int = 3) where {A}
    
Calculate the pose energy according to a single TorchANI model neural
network, using the XML-RPC protocol. If no TorchANI XML-RPC server is found, a
new one is spawned (in parallel) from file torchani_server.py. The model can be
defined using `model_index` (from model 1 to 8, default is 3). The optional `A`
parameter defines the acceleration mode used (only CUDA_2 is available). If left
undefined the default ProtoSyn.acceleration.active mode will be used. If
`update_forces` is set to true (false, by default), return the calculated forces
on each atom as well.

# See also
`calc_torchani_ensemble` `calc_torchani_model`

# Examples
```jldoctest
julia> Calculators.calc_torchani_model_xmlrpc(pose)
(...)
```

# Notes
If you use this function in a script, it is recommended to add
`ProtoSyn.Calculators.TorchANI.stop_torchANI_server()` at the end of the script,
as the automatic stopping of TorchANI XML-RPC server isn't finished.
"""
function calc_torchani_model_xmlrpc(::Type{ProtoSyn.CUDA_2}, pose::Pose; update_forces::Bool = false, model::Int = 3)

    # ! If an `IOError:("read: connection reset py peer, -104")` error is raised
    # ! when calling this function, check the GPU total allocation (using 
    # ! `nvidia-smi` on a command line or `ProtoSyn.gpu_allocation()` in a Julia
    # ! REPL). GPU might have 100% allocation.

    if server === nothing
        global proxy = start_torchANI_server()
    end

    c = collect(pose.state.x.coords')
    s = ProtoSyn.Calculators.TorchANI.get_ani_species(pose)
    response = proxy.calc(s, c, update_forces, model_index)
    println("Response: $response")
    xml_string = replace(join(Char.(response.body)), "\n" => "")
    xml = LightXML.parse_string(xml_string)
    
    r = Vector{Float64}()
    r_xml_travel!(xml, "double", r)
    if length(r) == 1
        sleep(0.001) # Required to prevent EOFError() during request
        return r[1], nothing
    else
        sleep(0.001) # Required to prevent EOFError() during request
        return splice!(r, 1), reshape(r, 3, :).*-1
    end
end

calc_torchani_model_xmlrpc(pose::Pose; update_forces::Bool = false, model::Int = 3) = begin
    calc_torchani_model_xmlrpc(ProtoSyn.acceleration.active, pose, update_forces = update_forces, model = model)
end

# * Default Energy Components --------------------------------------------------

function get_default_torchani_model_xmlrpc(α::T = 1.0) where {T <: AbstractFloat}
    return EnergyFunctionComponent(
        "TorchANI_ML_Model_XMLRPC",
        calc_torchani_model_xmlrpc,
        Dict{Symbol, Any}(:model => 3),
        α,
        true)
end