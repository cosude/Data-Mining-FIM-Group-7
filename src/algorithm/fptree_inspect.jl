# Mọi node của `item`, đi theo chuỗi node-link từ header table.
# 1. Phiên bản cho FPTree gốc (duyệt linked list)
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

# 2. Phiên bản cho OptFPTree tối ưu (trả về trực tiếp mảng nodes đã lưu, O(1))
function nodelinks(tree::OptFPTree{T}, item::T) where T
    haskey(tree.header_table, item) || return OptFPNode{T}[]
    return tree.header_table[item].nodes
end

# Số node của cây, không tính root.
# Đổi FPTree -> AbstractFPTree để nhận cả 2 cấu trúc
function count_nodes(tree::AbstractFPTree)
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
# Đổi FPTree -> AbstractFPTree
print_tree(tree::AbstractFPTree) = print_tree(stdout, tree)

function print_tree(io::IO, tree::AbstractFPTree)
    println(io, "null")
    _print_children(io, tree.root, "")
end

# Xóa định kiểu node::FPNode (hoặc dùng Union) để nhận cả FPNode và OptFPNode (Duck typing)
function _print_children(io::IO, node, prefix::String)
    kids = sort!(collect(values(node.children)); by = c -> (-c.count, c.item_name))
    for (i, child) in enumerate(kids)
        islast = i == length(kids)
        println(io, prefix, islast ? "└─ " : "├─ ", child.item_name, ":", child.count)
        _print_children(io, child, prefix * (islast ? "   " : "│  "))
    end
end