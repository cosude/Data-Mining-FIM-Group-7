abstract type AbstractFPTree end

mutable struct FPNode
    item_name::Union{Int, Nothing}
    count::Int
    node_link::Union{FPNode, Nothing}
    parent::Union{FPNode, Nothing}
    children::Dict{Int, FPNode}

    function FPNode(item_name::Union{Int, Nothing}, count::Int, parent::Union{FPNode, Nothing}=nothing)
        new(item_name, count, nothing, parent, Dict{Int, FPNode}())
    end
end

mutable struct HeaderTableEntry
    item_name::Int
    support::Int
    header_of_node_link::Union{FPNode, Nothing}
    tail_of_node_link::Union{FPNode, Nothing}

    function HeaderTableEntry(item_name::Int, support::Int=0)
        new(item_name, support, nothing, nothing)
    end
end

struct FPTree <: AbstractFPTree
    root::FPNode
    header_table::Dict{Int, HeaderTableEntry}
    flist::Vector{Int}

    function FPTree(header_table::Dict{Int, HeaderTableEntry}, flist::Vector{Int})
        root_node = FPNode(nothing, 0)
        new(root_node, header_table, flist)
    end
end

# Optimized version

# FPNode removed node_link
mutable struct OptFPNode
    item_name::Union{Int, Nothing}
    count::Int
    parent::Union{OptFPNode, Nothing}
    children::Dict{Int, OptFPNode}

    function OptFPNode(item_name::Union{Int, Nothing}, count::Int, parent::Union{OptFPNode, Nothing}=nothing)
        new(item_name, count, parent, Dict{Int, OptFPNode}())
    end
end

mutable struct OptHeaderTableEntry
    item_name::Int
    support::Int
    nodes::Vector{OptFPNode}
    
    function OptHeaderTableEntry(item_name::Int, support::Int=0)
        new(item_name, support, OptFPNode[])
    end
end

struct OptFPTree <: AbstractFPTree
    root::OptFPNode
    header_table::Dict{Int, OptHeaderTableEntry}

    function OptFPTree(header_table::Dict{Int, OptHeaderTableEntry})
        root_node = OptFPNode(nothing, 0)
        new(root_node, header_table)
    end
end