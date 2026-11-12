using Test
isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

# Ví dụ Table 1 trong bài báo, đổi chữ sang số: a=1 b=2 c=3 f=6 m=13 p=16 ...
const HAN_DB = read_spmf(joinpath(@__DIR__, "..", "data", "toy", "han2000.txt"))
const a, b, c, f, m, p = 1, 2, 3, 6, 13, 16

# Đi từ root theo đường item cho trước, trả về node cuối (hoặc nothing)
function walk(tree, path)
    node = tree.root
    for item in path
        node = get(node.children, item, nothing)
        node === nothing && return nothing
    end
    return node
end

# Hàm helper xử lý sự khác biệt cấu trúc khi lấy danh sách các node cùng item

@testset "FP-tree bước 1: support, FList, header table" begin
    support = count_supports(HAN_DB)
    @test support[c] == 4 && support[f] == 4 && support[a] == 3
    @test support[12] == 2 && support[19] == 1          # l:2, s:1

    # c và f cùng support 4, item nhỏ hơn (c=3) đứng trước
    FList = build_flist(support, 3)
    @test FList == [c, f, a, b, m, p]
    @test isempty(build_flist(support, 6))

    # Header Table
    ht = build_header_table(FList)
    @test sort(collect(keys(ht))) == sort(FList)
    @test all(ht[i].item_name == i && ht[i].header_of_node_link === nothing for i in FList)

    # Optimized Header Table
    opt_ht = build_opt_header_table(FList, support)
    @test sort(collect(keys(opt_ht))) == sort(FList)
    @test all(opt_ht[i].item_name == i && isempty(opt_ht[i].nodes) for i in FList)
end

@testset "FP-tree bước 2: fptree_construction ($name)" for (name, build_tree) in [
    ("Original", (db, minsup) -> fptree_construction(FPTree, db, minsup)),
    ("Optimized", (db, minsup) -> fptree_construction(OptFPTree, db, minsup))
]
    tree = build_tree(HAN_DB, 3)
    support = count_supports(HAN_DB)

    @testset "Hình dạng cây" begin
        expected = Dict(
            [c] => 4, [c, f] => 3, [c, f, a] => 3, [c, f, a, m] => 2,
            [c, f, a, m, p] => 2, [c, f, a, b] => 1, [c, f, a, b, m] => 1,
            [c, b] => 1, [c, b, p] => 1, [f] => 1, [f, b] => 1,
        )
        for (path, cnt) in expected
            node = walk(tree, path)
            @test node !== nothing && node.count == cnt
        end
        @test count_nodes(tree) == length(expected)
        @test length(tree.root.children) == 2
    end

    @testset "Node-link: tổng count bằng support" begin
        for item in keys(tree.header_table)
            nodes = nodelinks(tree, item)
            @test all(n.item_name == item for n in nodes)
            @test sum(n.count for n in nodes) == support[item]
        end
        @test length(nodelinks(tree, b)) == 3
    end

    @testset "Parent link" begin
        node = walk(tree, [c, f, a, m, p])
        path = Int[]
        while node.parent !== nothing
            push!(path, node.item_name)
            node = node.parent
        end
        @test reverse(path) == [c, f, a, m, p]
    end

    @testset "Trường hợp biên" begin
        @test count_nodes(build_tree(HAN_DB, 6)) == 0          # không item nào phổ biến
        @test count_nodes(build_tree(Vector{Int}[], 1)) == 0   # CSDL rỗng
        t = build_tree([[1, 2], [1, 2], [1, 2]], 1)            # 3 giao dịch giống nhau
        @test count_nodes(t) == 2 && walk(t, [1, 2]).count == 3
    end
end