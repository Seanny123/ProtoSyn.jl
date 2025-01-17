using Printf: @sprintf
using YAML

const PDB = Val{1}
const YML = Val{2}

function load(::Type{T}, filename::AbstractString) where {T<:AbstractFloat}
    endswith(filename, ".pdb") && return load(T, filename, PDB)
    endswith(filename, ".yml") && return load(T, filename, YML)
    error("Unable to load '$filename': unsupported file type")
end

load(::Type{T}, filename::AbstractString, ::Type{K}) where {T,K} = begin
    pose = load(T, open(filename), K)
    name,ext = splitext(basename(filename))
    pose.graph.name = name
    pose
end

load(filename::AbstractString) = load(Float64, filename)
load(filename::AbstractString, ::Type{K}) where K = load(Float64, filename, K)

#tonumber(v::Number) = v
#tonumber(v::String) = eval(Meta.parse(v))

load(::Type{T}, io::IO, ::Type{YML}) where {T<:AbstractFloat} = begin
    
    yml = YAML.load(io)
    natoms = length(yml["atoms"])
    
    state = State{T}(natoms)
    top = Topology(yml["name"], 1)
    seg = Segment!(top, top.name, 1)
    res = Residue!(seg, top.name, 1)
    
    #conv = haskey(yml, "unit") && yml["unit"]=="degrees"

    # add atoms
    for (index,pivot) in enumerate(yml["atoms"])
        atom = Atom!(res, pivot["name"], pivot["id"], index, pivot["symbol"])
        s = state[index]
        # if conv
        #     s.θ = deg2rad(pivot["theta"])
        #     s.ϕ = deg2rad(pivot["phi"])
        # else
        #     s.θ = pivot["theta"]
        #     s.ϕ = pivot["phi"]
        # end
        # s.b = T(pivot["b"])
        s.θ = tonumber(pivot["theta"])
        s.ϕ = tonumber(pivot["phi"])
        s.b = tonumber(pivot["b"])
    end

    # add bonds
    for (pivot,others) in yml["bonds"]
        atom = res[pivot]
        foreach(other->bond(atom,res[other]), others)
    end

    # bond graph
    graph = yml["graph"]
    for (pivot,others) in graph["adjacency"]
        atom = res[pivot]
        foreach(other->setparent!(res[other], atom), others)
    end

    root = origin(top)
    setparent!(
        res[graph["root"]],
        origin(top)
    )
    
    for atom in eachatom(top)
        atom.ascendents = ascendents(atom, 4)
    end

    request_i2c(state; all=true)
    top.id = state.id = genid()
    sync!(Pose(top, state))

end

# Base.read(::Type{T}, filename::AbstractString, ::Type{PDB}) where {T<:AbstractFloat} = begin
#     pose = open(filename) do fin
#         read(T, fin, PDB)
#     end
#     pose.graph.name = basename(filename)
#     pose
# end
# Base.read(filename::AbstractString, ::Type{PDB}) = read(Float64, filename, PDB)

load(::Type{T}, io::IO, ::Type{PDB}) where {T<:AbstractFloat} = begin
    
    top = Topology("UNK", -1)
    seg =  Segment("", -1)     # orphan segment
    res =  Residue("", -1)     # orphan residue
    
    seekstart(io)
    natoms = mapreduce(l->startswith(l, "ATOM")||startswith(l, "HETATM"), +, eachline(io); init=0)
    
    id2atom = Dict{Int,Atom}()
    
    state = State{T}(natoms)
    
    segid = atmindex = 1
    
    seekstart(io)
    for line in eachline(io)
        
        if startswith(line, "TITLE")
            top.name = string(strip(line[11:end]))

        elseif startswith(line, "ATOM") || startswith(line, "HETATM")
            
            resname = string(strip(line[18:20]))
            segname = string(strip(string(line[22])))
            resid = parse(Int, line[23:26])

            if seg.name != segname
                seg = Segment!(top, segname, segid)
                seg.code = isempty(segname) ? '-' : segname[1]
                segid += 1
            end

            if res.id != resid || res.name != resname
                res = Residue!(seg, resname, resid)
            end

            atsymbol = length(line)>77 ? string(strip(line[77:78])) : "?"
            atname = string(strip(line[13:16]))
            atid = parse(Int, line[7:11])

            atom = Atom!(res, atname, atid, atmindex, atsymbol)
            id2atom[atid] = atom
            
            s = state[atmindex]
            s.t[1] = parse(T, line[31:38])
            s.t[2] = parse(T, line[39:46])
            s.t[3] = parse(T, line[47:54])
            atmindex += 1

        elseif startswith(line, "CONECT")
            idxs = map(s->parse(Int, s), [line[n:n+4] for n=7:5:length(line)])
            pivot = id2atom[idxs[1]]
            for i in idxs[2:end]
                bond(pivot, id2atom[i])
            end
        end
    end
    top.id = state.id = genid()
    
    # request conversion from cartesian to internal
    # request_c2i(state; all=true)
    
    Pose(top,state)
end


write(io::IO, top::AbstractContainer, state::State) = begin
    
    println(io, "MODEL")
    for atom in eachatom(top)
        sti = state[atom.index]
        # s = @sprintf("ATOM %6d %4s %-4sA %3d    %8.3f%8.3f%8.3f%24s",
        s = @sprintf("ATOM  %5d %4s %3s %s%4d    %8.3f%8.3f%8.3f%24s",
            atom.index, atom.name,
            atom.container.name, atom.container.container.code,
            atom.container.id,
            sti.t[1], sti.t[2], sti.t[3],
            atom.symbol)
        println(io, s)
    end

    for atom in eachatom(top)
       print(io, @sprintf("CONECT%5d", atom.index))
       foreach(n->print(io, @sprintf("%5d",n.index)), atom.bonds)
       println(io,"")
    end
    println(io, "ENDMDL")
end

write(io::IO, pose::Pose) = write(io, pose.graph, pose.state)

write(io::IO, top::AbstractContainer, state::State, ::Type{YML}) = begin
    println(io, "name: ", top.name)
    println(io, "atoms:")
    
    byatom = eachatom(top)
    for at in byatom
        st = state[at]
        println(io,
            @sprintf("  - {name: %3s, id: %3d, symbol: %2s, b: %10.6f, theta: %10.6f, phi: %10.6f}",
            at.name, at.id, at.symbol, st.b, st.θ, st.ϕ)
        )
    end
    
    println(io, "bonds:")
    for at in byatom
        print(io, "  ", at.name, ": [")
        print(io, Base.join(map(a->a.name, at.bonds), ", "))
        println(io, "]")
    end

    println(io, "graph:")
    println(io, "  root: N")
    println(io, "  adjacency:")
    for at in byatom
        if haschildren(at)
            print(io, "    ", at.name, ": [")
            print(io, Base.join(map(a->a.name, at.children), ", "))
            println(io, "]")
        end
    end

end

write(io::IO, p::Pose, ::Type{T}) where T = write(io, p.graph, p.state, T)
