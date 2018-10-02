if Base.HOME_PROJECT[] !== nothing
    Base.HOME_PROJECT[] = abspath(Base.HOME_PROJECT[])
  end

using Documenter, ProtoSyn

push!(LOAD_PATH,"../src/")

makedocs(
    format = :html,
    sitename = "ProtoSyn.jl",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Forcefield" => "forcefield.md",
            
        ],
    ]
)

deploydoc(
    repo = "github.com/sergio-santos-group/ProtoSyn.jl.git",
    osname = "linux",
    julia = "1.0"
)
