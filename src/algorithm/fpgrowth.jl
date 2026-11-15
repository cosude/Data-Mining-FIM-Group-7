# Dispatch
function fpgrowth(
    ::Type{TreeType}, 
    DB::Vector{Vector{Int}}, 
    ξ::Int, 
    weights::Vector{Int}=ones(Int, length(DB))
) where TreeType
    tree = fptree_construction(TreeType, DB, ξ, weights)
    return fpgrowth(tree, ξ)
end

# Algorithm 2 (FP-growth), Han, Pei, Yin, Mao (2004), mục 3.

"""
    single_prefix_path(tree) -> (P, R)

Tách FP-tree theo mục 3.2 của bài báo. `P` là single prefix-path: chuỗi node đi từ root
xuống tới node rẽ nhánh đầu tiên (node có > 1 con; node này thuộc `P`, như (c:7) trong
Example 3). `R` là node mà phần multipath Q treo bên dưới, đóng vai trò pseudo-root của Q.

- Cây chỉ gồm một đường đơn: `P` là cả đường, `R` là node lá (không có con, nên Q rỗng).
- Root có > 1 con: `P` rỗng, `R` là root (Q chính là cả cây, dòng (8)).
"""
function single_prefix_path(tree::FPTree)
    P = FPNode[]
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
    out::Vector{Tuple{Vector{Int}, Int}},
    P::Vector{FPNode},
    idx::Int,
    current_items::Vector{Int},
    current_min_sup::Int
)
    if idx > length(P)
        isempty(current_items) || push!(out, (copy(current_items), current_min_sup))
        return
    end

    # Không lấy node thứ idx
    generate_combinations!(out, P, idx + 1, current_items, current_min_sup)

    # Lấy node thứ idx
    node = P[idx]
    push!(current_items, node.item_name::Int)
    generate_combinations!(out, P, idx + 1, current_items, min(current_min_sup, node.count))
    pop!(current_items) # quay lui
end

"""
    build_conditional_pattern_base(tree, item, R = tree.root) -> (paths, weights)

Dòng (11), Property 3.2: lần theo node-link của `item`; với mỗi node, đi ngược `parent`
lên tới `R` (root, hoặc pseudo-root của phần multipath Q) để lấy prefix path. Mỗi prefix
path mang count của node `item` tương ứng (transformed prefix path).
"""
function build_conditional_pattern_base(tree::FPTree, item::Int, R::FPNode=tree.root)
    paths = Vector{Int}[]
    weights = Int[]

    for node in nodelinks(tree, item)
        path = Int[]
        curr = node.parent
        while curr !== R
            push!(path, curr.item_name::Int)
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
    fpgrowth(tree::FPTree, ξ::Int) -> Vector{Tuple{Vector{Int}, Int}}
    
Algorithm 2: khai thác toàn bộ tập phổ biến từ `tree` (hoặc trực tiếp từ `DB`) với ngưỡng
support tuyệt đối `ξ`, bằng cách gọi FP-growth(FP-tree, null). Trả về các cặp
`(itemset, support)`; item trong itemset không được sắp theo thứ tự nào.
"""
function fpgrowth(tree::FPTree, ξ::Int)
    patterns = Tuple{Vector{Int}, Int}[]
    isempty(tree.root.children) || _fpgrowth!(patterns, tree, Int[], ξ)
    return patterns
end

# Procedure FP-growth(Tree, α). Các pattern sinh ra được ghi thêm vào `patterns`.
function _fpgrowth!(
    patterns::Vector{Tuple{Vector{Int}, Int}},
    tree::FPTree,
    α::Vector{Int},
    ξ::Int
)
    # (1)-(4) if Tree contains a single prefix path: P là single prefix-path,
    # Q là phần multipath bên dưới R (top branching node được thay bằng null root).
    # (8) else Q là cả Tree: khi đó P rỗng, R là root.
    P, R = single_prefix_path(tree)

    # (5)-(7) freq_pattern_set(P): mọi tổ hợp β của các node trên P,
    # support = min support của các node trong β. α được ghép vào ở dòng (15).
    freq_P = Tuple{Vector{Int}, Int}[]
    generate_combinations!(freq_P, P, 1, Int[], typemax(Int))

    # (9)-(14) freq_pattern_set(Q). Khi P rỗng thì kết quả cuối chính là freq_pattern_set(Q),
    # nên ghi thẳng vào `patterns` để khỏi sao chép.
    freq_Q = isempty(P) ? patterns : Tuple{Vector{Int}, Int}[]
    if !isempty(R.children)
        # Item thuộc P chỉ xuất hiện một lần trong cây, trên P (Lemma 3.3), nên các item
        # còn lại của FList chính là các item của Q, và mọi node của chúng nằm dưới R.
        items_P = Set{Int}(node.item_name::Int for node in P)
        for ai in Iterators.reverse(tree.flist) # từ đáy header table lên, như Example 2
            ai in items_P && continue

            # (10) generate pattern β = aᵢ ∪ α with support = aᵢ.support
            β = vcat(Int[ai], α)
            push!(freq_Q, (β, tree.header_table[ai].support))

            # (11) construct β's conditional pattern-base, then β's conditional FP-tree Tree_β
            cond_paths, cond_weights = build_conditional_pattern_base(tree, ai, R)
            isempty(cond_paths) && continue
            tree_beta = fptree_construction(FPTree, cond_paths, ξ, cond_weights)

            # (12)-(13) if Tree_β ≠ ∅ then call FP-growth(Tree_β, β)
            isempty(tree_beta.root.children) || _fpgrowth!(freq_Q, tree_beta, β, ξ)
        end
    end

    # (15) return freq_pattern_set(P) ∪ freq_pattern_set(Q) ∪ (freq_pattern_set(P) × freq_pattern_set(Q))
    isempty(P) && return patterns # freq_P rỗng, freq_Q đã nằm trong `patterns`
    for (β, sup) in freq_P
        push!(patterns, (vcat(β, α), sup))
    end
    append!(patterns, freq_Q)
    for (q, sup_q) in freq_Q, (β, sup_beta) in freq_P
        # q đã chứa α; support = min của hai pattern (luôn là sup_q, Lemma 3.3)
        push!(patterns, (vcat(β, q), min(sup_q, sup_beta)))
    end
    return patterns
end

# Optimized version
function fpgrowth(tree::OptFPTree, minsup::Int)
    results = Tuple{Vector{Int}, Int}[]
    _fpgrowth_step!(tree, Int[], minsup, results)
    return results
end

function _fpgrowth_step!(
    tree::OptFPTree, 
    α::Vector{Int}, 
    ξ::Int, 
    results::Vector{Tuple{Vector{Int}, Int}}
)
    # Optimize by checking for single prefix path
    is_single_path = true
    current = tree.root
    path_nodes = OptFPNode[]
    
    while !isempty(current.children)
        # If the node has more than one child, its no longer a single path
        if length(current.children) > 1
            is_single_path = false
            break
        end
        # Move to the single child, push it to the path
        current = first(values(current.children))
        push!(path_nodes, current)
    end

    if is_single_path
        n = length(path_nodes)
        # Using bitwise to generate combinations:
        for i in 1:(2^n - 1) # Looping from 1 -> 2^n - 1, each iter is a unique bit mask, ex: n = 5, i = 12 => mask = 01100
            β = copy(α)
            min_sup_beta = typemax(Int)
            
            for j in 1:n # Looping through the bits of i
                if (i & (1 << (j - 1))) != 0 # Checking if the mask's j-1th right-to-left bit is 1 => the mask includes the j item, otherwise exclude it
                    push!(β, path_nodes[j].item_name)
                    min_sup_beta = min(min_sup_beta, path_nodes[j].count) # Update min sup
                end
            end
            push!(results, (β, min_sup_beta))
        end
        return # Skip recursion
    end

    # Optimize by sort header table entries ascending once
    sorted_items = sort(collect(keys(tree.header_table)), by = x -> tree.header_table[x].support)
    
    for item in sorted_items
        entry = tree.header_table[item]
        beta_support = entry.support
        
        β = copy(α)
        push!(β, item)
        push!(results, (β, beta_support))
        
        cond_pattern_base = Vector{Int}[]
        cond_counts = Int[]
        
        for node in entry.nodes # Looping through every nodes of the item from the header table entry
            prefix_path = Int[]
            parent = node.parent
            
            # Traverse to root
            while parent !== nothing && parent.item_name !== nothing
                push!(prefix_path, parent.item_name)
                parent = parent.parent
            end
            
            if !isempty(prefix_path)
                reverse!(prefix_path) # Reverse the path (since traveled backwards)
                push!(cond_pattern_base, prefix_path)
                push!(cond_counts, node.count) # The path's support is its last node's support
            end
        end
        
        isempty(cond_pattern_base) && continue
        
        # Checking support (frequency) of each items in all the paths found
        local_support = Dict{Int, Int}()
        for (i, path) in enumerate(cond_pattern_base)
            count_i = cond_counts[i]
            for p_item in path
                local_support[p_item] = get(local_support, p_item, 0) + count_i
            end
        end
        
        # Sort them
        freq_items = [k for (k, v) in local_support if v >= ξ]
        isempty(freq_items) && continue
        sort!(freq_items, by = k -> (-local_support[k], k))
        
        # Initialize the conditional fptree
        cond_header = build_opt_header_table(freq_items, local_support)
        cond_tree = OptFPTree(cond_header)
        
        # Build the conditional fptree
        for (i, path) in enumerate(cond_pattern_base)
            filtered_path = Int[]
            # Maintain the order of new frequent items
            for fi in freq_items
                if fi in path
                    push!(filtered_path, fi)
                end
            end
            
            if !isempty(filtered_path)
                _insert_cond_tree_iterative!(cond_tree, filtered_path, cond_counts[i])
            end
        end
        
        # Recursion
        _fpgrowth_step!(cond_tree, β, ξ, results)
    end
end

function _insert_cond_tree_iterative!(tree::OptFPTree, items::Vector{Int}, count::Int)
    current_node = tree.root
    for item in items
        if haskey(current_node.children, item)
            current_node = current_node.children[item]
            current_node.count += count
        else
            new_node = OptFPNode(item, count, current_node)
            current_node.children[item] = new_node
            
            push!(tree.header_table[item].nodes, new_node)
            current_node = new_node
        end
    end
end
