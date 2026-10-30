# Cấu trúc dữ liệu của FP-tree (Han, Pei, Yin, 2000).

"""
Một node của FP-tree. Root có `item = 0` (nhãn "null" trong bài báo).
"""
mutable struct FPNode
    item::Int
    count::Int
    parent::Union{FPNode,Nothing}
    children::Dict{Int,FPNode}        # item => node con
    nodelink::Union{FPNode,Nothing}   # node kế tiếp có cùng item
end

FPNode(item::Int, count::Int, parent::Union{FPNode,Nothing}) =
    FPNode(item, count, parent, Dict{Int,FPNode}(), nothing)

"""
FP-tree kèm header table. `header[i]` là node đầu tiên của chuỗi node-link của
item `i`, `last[i]` là node cuối để nối thêm node mới trong O(1).
"""
struct FPTree
    root::FPNode
    flist::Vector{Int}          # item phổ biến, support giảm dần
    rank::Dict{Int,Int}         # item => vị trí trong flist
    support::Dict{Int,Int}      # item => support
    header::Dict{Int,FPNode}
    last::Dict{Int,FPNode}
end

function FPTree(flist::Vector{Int}, support::Dict{Int,Int})
    rank = Dict(item => i for (i, item) in enumerate(flist))
    return FPTree(FPNode(0, 0, nothing), flist, rank, support,
                  Dict{Int,FPNode}(), Dict{Int,FPNode}())
end
