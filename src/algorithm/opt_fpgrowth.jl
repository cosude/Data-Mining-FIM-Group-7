function mine_fpgrowth_opt(tree::OptFPTree{Int}, minsup::Int)
    results = Tuple{Vector{Int}, Int}[]
    _fpgrowth_opt_step!(tree, Int[], minsup, results)
    return results
end

function _fpgrowth_opt_step!(
    tree::OptFPTree{Int}, 
    alpha::Vector{Int}, 
    minsup::Int, 
    results::Vector{Tuple{Vector{Int}, Int}}
)
    # Optimize by checking for single prefix path
    is_single_path = true
    current = tree.root
    path_nodes = OptFPNode{Int}[]
    
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
            beta = copy(alpha)
            min_sup_beta = typemax(Int)
            
            for j in 1:n # Looping through the bits of i
                if (i & (1 << (j - 1))) != 0 # Checking if the mask's j-1th right-to-left bit is 1 => the mask includes the j item, otherwise exclude it
                    push!(beta, path_nodes[j].item_name)
                    min_sup_beta = min(min_sup_beta, path_nodes[j].count) # Update min sup
                end
            end
            push!(results, (beta, min_sup_beta))
        end
        return # Skip recursion
    end

    # Optimize by sort header table entries ascending once
    sorted_items = sort(collect(keys(tree.header_table)), by = x -> tree.header_table[x].support)
    
    for item in sorted_items
        entry = tree.header_table[item]
        beta_support = entry.support
        
        beta = copy(alpha)
        push!(beta, item)
        push!(results, (beta, beta_support))
        
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
        freq_items = [k for (k, v) in local_support if v >= minsup]
        isempty(freq_items) && continue
        sort!(freq_items, by = k -> (-local_support[k], k))
        
        # Initialize the conditional fptree
        cond_header = build_opt_header_table(freq_items, local_support)
        cond_tree = OptFPTree{Int}(cond_header)
        
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
        _fpgrowth_opt_step!(cond_tree, beta, minsup, results)
    end
end

function _insert_cond_tree_iterative!(tree::OptFPTree{Int}, items::Vector{Int}, count::Int)
    current_node = tree.root
    for item in items
        if haskey(current_node.children, item)
            current_node = current_node.children[item]
            current_node.count += count
        else
            new_node = OptFPNode{Int}(item, count, current_node)
            current_node.children[item] = new_node
            
            push!(tree.header_table[item].nodes, new_node)
            current_node = new_node
        end
    end
end