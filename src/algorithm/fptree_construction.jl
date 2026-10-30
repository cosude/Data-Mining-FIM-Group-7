include("../utils.jl")
include("../structures.jl")

function fptree_construction(DB::Vector{Vector{T}}, ξ::Int) where T
    # 1. Scan the transaction database DB once. Collect F, the set of frequent items, and the
    # support of each frequent item. Sort F in support-descending order as FList, the list of
    # frequent items

    # 2. Create the root of an FP-tree, T , and label it as “null”. 
    tree = FPTree{T}(header_table)
    T_node = tree.root
    
    # For each transaction Trans in DB do the following.
    for Trans in DB
        # Select the frequent items in Trans and sort them according to the order of FList. Let the
        # sorted frequent-item list in Trans be [p | P], where p is the first element and P is the
        # remaining list.
        sorted_frequent_items = filter_and_sort(Trans, FList)
        
        if !isempty(sorted_frequent_items)
            # Call insert_tree([p | P], T)
            insert_tree!(tree, sorted_frequent_items, T_node)
        end
    end

    return tree
end

# The function insert_tree([p | P], T) is performed as follows.
function insert_tree!(tree::FPTree{ItemType}, p_P::AbstractVector{ItemType}, T_node::FPNode{ItemType}) where ItemType
    # p is the first element and P is the remaining list
    p = p_P[1] 
    
    # If T has a child N such that N.item-name = p.item-name
    if haskey(T_node.children, p)
        N = T_node.children[p]
        # then increment N's count by 1
        N.count += 1
    else
        # else create a new node N, with its count initialized to 1, 
        # its parent link linked to T
        N = FPNode{ItemType}(p, 1, T_node)
        T_node.children[p] = N # Add to T's children
        
        # and its node-link linked to the nodes with the same item-name 
        # via the node-link structure.
        entry = tree.header_table[p]
        if entry.header_of_node_link === nothing
            entry.header_of_node_link = N
        else
            # Traverse to the end of the node-link chain to link the new node
            current_link = entry.header_of_node_link
            while current_link.node_link !== nothing
                current_link = current_link.node_link
            end
            current_link.node_link = N
        end
    end
    
    # If P is nonempty, call insert_tree(P, N) recursively.
    if length(p_P) > 1
        P = p_P[2:end] # P is the remaining list
        insert_tree!(tree, P, N)
    end
end