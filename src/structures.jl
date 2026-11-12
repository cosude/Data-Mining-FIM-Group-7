abstract type AbstractFPTree{T} end

mutable struct FPNode{T}
    item_name::Union{T, Nothing}
    count::Int
    node_link::Union{FPNode{T}, Nothing}
    parent::Union{FPNode{T}, Nothing}
    children::Dict{T, FPNode{T}}

    function FPNode{T}(item_name::Union{T, Nothing}, count::Int, parent::Union{FPNode{T}, Nothing}=nothing) where T
        new{T}(item_name, count, nothing, parent, Dict{T, FPNode{T}}())
    end
end

mutable struct HeaderTableEntry{T}
    item_name::T
    support::Int
    header_of_node_link::Union{FPNode{T}, Nothing}
    tail_of_node_link::Union{FPNode{T}, Nothing} # last node of the chain, for O(1) append

    function HeaderTableEntry{T}(item_name::T, support::Int=0) where T
        new{T}(item_name, support, nothing, nothing)
    end
end

struct FPTree{T} <: AbstractFPTree{T}
    root::FPNode{T}
    header_table::Dict{T, HeaderTableEntry{T}}
    flist::Vector{T} # frequent items sorted by descending support

    function FPTree{T}(header_table::Dict{T, HeaderTableEntry{T}}, flist::Vector{T}) where T
        root_node = FPNode{T}(nothing, 0)
        new{T}(root_node, header_table, flist)
    end
end

# Optimized version

# FPNode removed node_link
mutable struct OptFPNode{T}
    item_name::Union{T, Nothing}
    count::Int
    parent::Union{OptFPNode{T}, Nothing}
    children::Dict{T, OptFPNode{T}}

    function OptFPNode{T}(item_name::Union{T, Nothing}, count::Int, parent::Union{OptFPNode{T}, Nothing}=nothing) where T
        new{T}(item_name, count, parent, Dict{T, OptFPNode{T}}())
    end
end

# HeaderTableEntry references nodes using a vector => O(1) look up for paths
mutable struct OptHeaderTableEntry{T}
    item_name::T
    support::Int
    nodes::Vector{OptFPNode{T}}
    
    function OptHeaderTableEntry{T}(item_name::T, support::Int=0) where T
        new{T}(item_name, support, OptFPNode{T}[])
    end
end

struct OptFPTree{T} <: AbstractFPTree{T}
    root::OptFPNode{T}
    header_table::Dict{T, OptHeaderTableEntry{T}}

    function OptFPTree{T}(header_table::Dict{T, OptHeaderTableEntry{T}}) where T
        root_node = OptFPNode{T}(nothing, 0)
        new{T}(root_node, header_table)
    end
end