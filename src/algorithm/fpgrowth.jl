# Algorithm 2 (FP-growth), Han, Pei, Yin, Mao (2004), mục 3.

"""
    single_prefix_path(tree) -> (P, R)

Tách FP-tree theo mục 3.2 của bài báo. `P` là single prefix-path: chuỗi node đi từ root
xuống tới node rẽ nhánh đầu tiên (node có > 1 con; node này thuộc `P`, như (c:7) trong
Example 3). `R` là node mà phần multipath Q treo bên dưới, đóng vai trò pseudo-root của Q.

- Cây chỉ gồm một đường đơn: `P` là cả đường, `R` là node lá (không có con, nên Q rỗng).
- Root có > 1 con: `P` rỗng, `R` là root (Q chính là cả cây, dòng (8)).
"""
function single_prefix_path(tree::FPTree{T}) where T
    P = FPNode{T}[]
    R = tree.root
    while length(R.children) == 1
        R = first(values(R.children))
        push!(P, R)
    end
    return P, R
end

"""
    generate_combinations!(out, P, idx, current_items, current_min_sup)

Dòng (5)-(6): sinh mọi tổ hợp con khác rỗng β của các node trên đường đơn `P` (quay lui),
với support = support nhỏ nhất của các node trong β (Lemma 3.2).
"""
function generate_combinations!(
    out::Vector{Tuple{Vector{T}, Int}},
    P::Vector{FPNode{T}},
    idx::Int,
    current_items::Vector{T},
    current_min_sup::Int
) where T
    if idx > length(P)
        isempty(current_items) || push!(out, (copy(current_items), current_min_sup))
        return
    end

    # Không lấy node thứ idx
    generate_combinations!(out, P, idx + 1, current_items, current_min_sup)

    # Lấy node thứ idx
    node = P[idx]
    push!(current_items, node.item_name::T)
    generate_combinations!(out, P, idx + 1, current_items, min(current_min_sup, node.count))
    pop!(current_items) # quay lui
end

"""
    build_conditional_pattern_base(tree, item, R = tree.root) -> (paths, weights)

Dòng (11), Property 3.2: lần theo node-link của `item`; với mỗi node, đi ngược `parent`
lên tới `R` (root, hoặc pseudo-root của phần multipath Q) để lấy prefix path. Mỗi prefix
path mang count của node `item` tương ứng (transformed prefix path).
"""
function build_conditional_pattern_base(tree::FPTree{T}, item::T, R::FPNode{T}=tree.root) where T
    paths = Vector{T}[]
    weights = Int[]

    for node in nodelinks(tree, item)
        path = T[]
        curr = node.parent
        while curr !== R
            push!(path, curr.item_name::T)
            curr = curr.parent
        end

        if !isempty(path)
            reverse!(path) # đường đi từ trên xuống, đúng thứ tự FList
            push!(paths, path)
            push!(weights, node.count)
        end
    end

    return paths, weights
end

"""
    fpgrowth(tree::FPTree{T}, ξ::Int) -> Vector{Tuple{Vector{T}, Int}}
    fpgrowth(DB::Vector{Vector{T}}, ξ::Int) -> Vector{Tuple{Vector{T}, Int}}

Algorithm 2: khai thác toàn bộ tập phổ biến từ `tree` (hoặc trực tiếp từ `DB`) với ngưỡng
support tuyệt đối `ξ`, bằng cách gọi FP-growth(FP-tree, null). Trả về các cặp
`(itemset, support)`; item trong itemset không được sắp theo thứ tự nào.
"""
function fpgrowth(tree::FPTree{T}, ξ::Int) where T
    patterns = Tuple{Vector{T}, Int}[]
    isempty(tree.root.children) || _fpgrowth!(patterns, tree, T[], ξ)
    return patterns
end

fpgrowth(DB::Vector{Vector{T}}, ξ::Int) where T = fpgrowth(fptree_construction(DB, ξ), ξ)

# Procedure FP-growth(Tree, α). Các pattern sinh ra được ghi thêm vào `patterns`.
function _fpgrowth!(
    patterns::Vector{Tuple{Vector{T}, Int}},
    tree::FPTree{T},
    alpha::Vector{T},
    ξ::Int
) where T
    # (1)-(4) if Tree contains a single prefix path: P là single prefix-path,
    # Q là phần multipath bên dưới R (top branching node được thay bằng null root).
    # (8) else Q là cả Tree: khi đó P rỗng, R là root.
    P, R = single_prefix_path(tree)

    # (5)-(7) freq_pattern_set(P): mọi tổ hợp β của các node trên P,
    # support = min support của các node trong β. α được ghép vào ở dòng (15).
    freq_P = Tuple{Vector{T}, Int}[]
    generate_combinations!(freq_P, P, 1, T[], typemax(Int))

    # (9)-(14) freq_pattern_set(Q). Khi P rỗng thì kết quả cuối chính là freq_pattern_set(Q),
    # nên ghi thẳng vào `patterns` để khỏi sao chép.
    freq_Q = isempty(P) ? patterns : Tuple{Vector{T}, Int}[]
    if !isempty(R.children)
        # Item thuộc P chỉ xuất hiện một lần trong cây, trên P (Lemma 3.3), nên các item
        # còn lại của FList chính là các item của Q, và mọi node của chúng nằm dưới R.
        items_P = Set{T}(node.item_name::T for node in P)
        for ai in Iterators.reverse(tree.flist) # từ đáy header table lên, như Example 2
            ai in items_P && continue

            # (10) generate pattern β = aᵢ ∪ α with support = aᵢ.support
            beta = vcat(T[ai], alpha)
            push!(freq_Q, (beta, tree.header_table[ai].support))

            # (11) construct β's conditional pattern-base, then β's conditional FP-tree Tree_β
            cond_paths, cond_weights = build_conditional_pattern_base(tree, ai, R)
            isempty(cond_paths) && continue
            tree_beta = fptree_construction(cond_paths, ξ, cond_weights)

            # (12)-(13) if Tree_β ≠ ∅ then call FP-growth(Tree_β, β)
            isempty(tree_beta.root.children) || _fpgrowth!(freq_Q, tree_beta, beta, ξ)
        end
    end

    # (15) return freq_pattern_set(P) ∪ freq_pattern_set(Q) ∪ (freq_pattern_set(P) × freq_pattern_set(Q))
    isempty(P) && return patterns # freq_P rỗng, freq_Q đã nằm trong `patterns`
    for (beta, sup) in freq_P
        push!(patterns, (vcat(beta, alpha), sup))
    end
    append!(patterns, freq_Q)
    for (q, sup_q) in freq_Q, (beta, sup_beta) in freq_P
        # q đã chứa α; support = min của hai pattern (luôn là sup_q, Lemma 3.3)
        push!(patterns, (vcat(beta, q), min(sup_q, sup_beta)))
    end
    return patterns
end
