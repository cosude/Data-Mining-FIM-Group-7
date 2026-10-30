# Hàm phụ để kiểm tra và in FP-tree (dùng trong test và demo).

# Mọi node của `item`, đi theo chuỗi node-link từ header table.
function nodelinks(tree::FPTree{T}, item::T) where T
    nodes = FPNode{T}[]
    haskey(tree.header_table, item) || return nodes
    node = tree.header_table[item].header_of_node_link
    while node !== nothing
        push!(nodes, node)
        node = node.node_link
    end
    return nodes
end

# Số node của cây, không tính root.
function count_nodes(tree::FPTree)
    total = 0
    stack = [tree.root]
    while !isempty(stack)
        node = pop!(stack)
        total += length(node.children)
        append!(stack, values(node.children))
    end
    return total
end

# In cây dạng ASCII; các con sắp theo count giảm dần, rồi theo item.
print_tree(tree::FPTree) = print_tree(stdout, tree)

function print_tree(io::IO, tree::FPTree)
    println(io, "null")
    _print_children(io, tree.root, "")
end

function _print_children(io::IO, node::FPNode, prefix::String)
    kids = sort!(collect(values(node.children)); by = c -> (-c.count, c.item_name))
    for (i, child) in enumerate(kids)
        islast = i == length(kids)
        println(io, prefix, islast ? "└─ " : "├─ ", child.item_name, ":", child.count)
        _print_children(io, child, prefix * (islast ? "   " : "│  "))
    end
end
