# Algorithm 1 (FP-tree construction), bước 1, Han, Pei, Yin (2000).

"""
    count_supports(DB) -> Dict{Int,Int}

Quét CSDL lần thứ nhất: đếm support của từng item.
"""
function count_supports(DB::Vector{Vector{Int}}, weights::Vector{Int}=ones(Int, length(DB)))
    support = Dict{Int,Int}()
    for (Trans, w) in zip(DB, weights)
        for item in Trans
            support[item] = get(support, item, 0) + w
        end
    end
    return support
end

"""
    build_flist(support, ξ) -> Vector{Int}

Giữ các item có support >= ξ (tập F) và sắp theo support giảm dần (FList). Cùng
support thì item nhỏ hơn đứng trước (cùng quy tắc với SPMF).
"""
function build_flist(support::Dict{Int,Int}, ξ::Int)
    FList = Int[item for (item, sup) in support if sup >= ξ]
    sort!(FList; by = item -> (-support[item], item))
    return FList
end

"""
    build_header_table(FList, support) -> Dict{Int,HeaderTableEntry}

Tạo header table, mỗi frequent item một entry kèm support của nó (dùng ở dòng (10)
của Algorithm 2); node-link được nối ở bước 2.
"""
function build_header_table(FList::Vector{Int}, support::Dict{Int, Int})
    return Dict{Int,HeaderTableEntry}(item => HeaderTableEntry(item, support[item]) for item in FList)
end

# Optimized build_header_table
function build_opt_header_table(FList::Vector{Int}, support::Dict{Int,Int})
    return Dict{Int,OptHeaderTableEntry}(
        item => OptHeaderTableEntry(item, support[item]) for item in FList
    )
end