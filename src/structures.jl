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
    header_of_node_link::Union{FPNode{T}, Nothing}

    function HeaderTableEntry{T}(item_name::T) where T
        new{T}(item_name, nothing)
    end
end

struct FPTree{T}
    root::FPNode{T}
    header_table::Dict{T, HeaderTableEntry{T}}

    function FPTree{T}(header_table::Dict{T, HeaderTableEntry{T}}) where T
        root_node = FPNode{T}(nothing, 0)
        new{T}(root_node, header_table)
    end
end