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

# Algorithm 2 (FP-growth), Han, Pei, Yin (2000), mục 3.

"""
    single_path(tree) -> Union{Vector{FPNode}, Nothing}

Dòng (1): kiểm tra cả `tree` có phải một đường đơn hay không, tức là mọi node (kể cả root)
có không quá một con. Nếu đúng, trả về các node trên đường đó theo thứ tự từ root xuống;
nếu cây rẽ nhánh ở bất kỳ đâu, trả về `nothing`.
"""
function single_path(tree::FPTree)
    P = FPNode[]
    node = tree.root
    while true
        n = length(node.children)
        n == 0 && return P          # tới lá: cả cây là một đường đơn
        n > 1 && return nothing     # có rẽ nhánh: không phải đường đơn
        node = first(values(node.children))
        push!(P, node)
    end
end

"""
    generate_combinations!(out, P, α, idx, current_items, current_min_sup)

Dòng (2)-(3): sinh mọi tổ hợp con khác rỗng β của các node trên đường đơn `P` (quay lui),
ghi pattern β ∪ α với support = support nhỏ nhất của các node trong β (Lemma 3.2).
"""
function generate_combinations!(
    out::Vector{Tuple{Vector{Int}, Int}},
    P::Vector{FPNode},
    α::Vector{Int},
    idx::Int,
    current_items::Vector{Int},
    current_min_sup::Int
)
    if idx > length(P)
        isempty(current_items) || push!(out, (vcat(current_items, α), current_min_sup))
        return
    end

    # Không lấy node thứ idx
    generate_combinations!(out, P, α, idx + 1, current_items, current_min_sup)

    # Lấy node thứ idx
    node = P[idx]
    push!(current_items, node.item_name::Int)
    generate_combinations!(out, P, α, idx + 1, current_items, min(current_min_sup, node.count))
    pop!(current_items) # quay lui
end

"""
    build_conditional_pattern_base(tree, item) -> (paths, weights)

Dòng (6): lần theo node-link của `item` (Property 3.1); với mỗi node, đi ngược `parent` lên
tới root để lấy prefix path. Mỗi prefix path mang count của node `item` tương ứng
(transformed prefix path, Property 3.2).
"""
function build_conditional_pattern_base(tree::FPTree, item::Int)
    paths = Vector{Int}[]
    weights = Int[]

    for node in nodelinks(tree, item)
        path = Int[]
        curr = node.parent
        while curr !== tree.root
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
    # (1) if Tree contains a single path P
    P = single_path(tree)
    if P !== nothing
        # (2)-(3) then for each combination β of the nodes in P:
        # generate pattern β ∪ α with support = minimum support of nodes in β
        generate_combinations!(patterns, P, α, 1, Int[], typemax(Int))
        return patterns
    end

    # (4) else for each aᵢ in the header of Tree (từ đáy header table lên, như Example 2)
    for ai in Iterators.reverse(tree.flist)
        # (5) generate pattern β = aᵢ ∪ α with support = aᵢ.support
        β = vcat(Int[ai], α)
        push!(patterns, (β, tree.header_table[ai].support))

        # (6) construct β's conditional pattern base and then β's conditional FP-tree Tree_β
        cond_paths, cond_weights = build_conditional_pattern_base(tree, ai)
        isempty(cond_paths) && continue
        tree_beta = fptree_construction(FPTree, cond_paths, ξ, cond_weights)

        # (7)-(8) if Tree_β ≠ ∅ then call FP-growth(Tree_β, β)
        isempty(tree_beta.root.children) || _fpgrowth!(patterns, tree_beta, β, ξ)
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
