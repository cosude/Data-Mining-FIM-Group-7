# Algorithm 1 (FP-tree construction), Han, Pei, Yin (2000).

"""
    count_supports(db) -> Dict{Int,Int}

Bước 1, quét CSDL lần thứ nhất: đếm support của từng item.
"""
function count_supports(db::Vector{Vector{Int}})::Dict{Int,Int}
    support = Dict{Int,Int}()
    for trans in db, item in trans
        support[item] = get(support, item, 0) + 1
    end
    return support
end

"""
    build_flist(support, minsup_count) -> Vector{Int}

Giữ các item có support >= minsup_count và sắp theo support giảm dần. Cùng
support thì item nhỏ hơn đứng trước (cùng quy tắc với SPMF).
"""
function build_flist(support::Dict{Int,Int}, minsup_count::Int)::Vector{Int}
    flist = [item for (item, sup) in support if sup >= minsup_count]
    sort!(flist; by = item -> (-support[item], item))
    return flist
end

"""
    insert_tree!(tree, items, count = 1)

Chèn một danh sách item đã sắp theo F-list vào cây, tương ứng `insert_tree([p|P], T)`
trong bài báo. Viết bằng vòng lặp thay cho đệ quy: mỗi vòng xử lý phần tử đầu `p`,
rồi đi xuống node `N` để xử lý phần còn lại `P`. `count` > 1 dùng khi dựng
conditional FP-tree.
"""
function insert_tree!(tree::FPTree, items::AbstractVector{Int}, count::Int = 1)
    node = tree.root
    for p in items
        child = get(node.children, p, nothing)
        if child === nothing
            # Tạo node mới N, count = count, parent = T, nối vào chuỗi node-link của p
            child = FPNode(p, count, node)
            node.children[p] = child
            if haskey(tree.last, p)
                tree.last[p].nodelink = child
            else
                tree.header[p] = child
            end
            tree.last[p] = child
        else
            # Đã có con N cùng item-name: tăng count
            child.count += count
        end
        node = child
    end
    return tree
end

"""
    build_fptree(db, minsup_count) -> FPTree

Xây FP-tree với 2 lần quét CSDL: lần 1 tìm F-list, lần 2 chèn từng giao dịch đã
lọc item không phổ biến và sắp theo thứ tự F-list.
"""
function build_fptree(db::Vector{Vector{Int}}, minsup_count::Int)::FPTree
    support = count_supports(db)
    flist = build_flist(support, minsup_count)
    tree = FPTree(flist, Dict(item => support[item] for item in flist))

    buf = Int[]
    for trans in db
        empty!(buf)
        for item in trans
            haskey(tree.rank, item) && push!(buf, item)
        end
        sort!(buf; by = item -> tree.rank[item])
        insert_tree!(tree, buf)
    end
    return tree
end

"""
    nodelinks(tree, item) -> Vector{FPNode}

Trả về mọi node của `item`, đi theo chuỗi node-link từ header table.
"""
function nodelinks(tree::FPTree, item::Int)::Vector{FPNode}
    nodes = FPNode[]
    node = get(tree.header, item, nothing)
    while node !== nothing
        push!(nodes, node)
        node = node.nodelink
    end
    return nodes
end

"""
    count_nodes(tree) -> Int

Số node của cây, không tính root.
"""
function count_nodes(tree::FPTree)::Int
    total = 0
    stack = [tree.root]
    while !isempty(stack)
        node = pop!(stack)
        total += length(node.children)
        append!(stack, values(node.children))
    end
    return total
end

"""
    print_tree([io], tree)

In cây dạng ASCII, các con sắp theo thứ tự F-list.
"""
print_tree(tree::FPTree) = print_tree(stdout, tree)

function print_tree(io::IO, tree::FPTree)
    println(io, "null")
    _print_children(io, tree, tree.root, "")
end

function _print_children(io::IO, tree::FPTree, node::FPNode, prefix::String)
    kids = sort!(collect(values(node.children)); by = c -> tree.rank[c.item])
    for (i, child) in enumerate(kids)
        islast = i == length(kids)
        println(io, prefix, islast ? "└─ " : "├─ ", child.item, ":", child.count)
        _print_children(io, tree, child, prefix * (islast ? "   " : "│  "))
    end
end
