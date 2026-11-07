# Algorithm 1 (FP-tree construction), bước 1, Han, Pei, Yin (2000).

"""
    count_supports(DB) -> Dict{T,Int}

Quét CSDL lần thứ nhất: đếm support của từng item.
"""
function count_supports(DB::Vector{Vector{T}}) where T
    support = Dict{T,Int}()
    for Trans in DB, item in Trans
        support[item] = get(support, item, 0) + 1
    end
    return support
end

"""
    build_flist(support, ξ) -> Vector{T}

Giữ các item có support >= ξ (tập F) và sắp theo support giảm dần (FList). Cùng
support thì item nhỏ hơn đứng trước (cùng quy tắc với SPMF).
"""
function build_flist(support::Dict{T,Int}, ξ::Int) where T
    FList = T[item for (item, sup) in support if sup >= ξ]
    sort!(FList; by = item -> (-support[item], item))
    return FList
end

"""
    build_header_table(FList) -> Dict{T,HeaderTableEntry{T}}

Tạo header table rỗng, mỗi frequent item một entry; node-link được nối ở bước 2.
"""
function build_header_table(FList::Vector{T}) where T
    return Dict{T,HeaderTableEntry{T}}(item => HeaderTableEntry{T}(item) for item in FList)
end

# Optimized build_header_table
function build_opt_header_table(FList::Vector{T}, support::Dict{T,Int}) where T
    return Dict{T,OptHeaderTableEntry{T}}(
        item => OptHeaderTableEntry{T}(item, support[item]) for item in FList
    )
end