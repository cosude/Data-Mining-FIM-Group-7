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

@testset "FP-tree construction" begin
    tree = build_fptree(HAN_DB, 3)

    @testset "F-list và support" begin
        # c và f cùng support 4, item nhỏ hơn (c=3) đứng trước
        @test tree.flist == [c, f, a, b, m, p]
        @test tree.support == Dict(c => 4, f => 4, a => 3, b => 3, m => 3, p => 3)
    end

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
        for item in tree.flist
            nodes = nodelinks(tree, item)
            @test all(n.item == item for n in nodes)
            @test sum(n.count for n in nodes) == tree.support[item]
            @test tree.last[item] === nodes[end]
        end
        @test length(nodelinks(tree, b)) == 3
    end

    @testset "Parent link" begin
        node = walk(tree, [c, f, a, m, p])
        path = Int[]
        while node.parent !== nothing
            push!(path, node.item)
            node = node.parent
        end
        @test reverse(path) == [c, f, a, m, p]
    end

    @testset "Trường hợp biên" begin
        @test count_nodes(build_fptree(HAN_DB, 6)) == 0           # không item nào phổ biến
        @test count_nodes(build_fptree(Vector{Int}[], 1)) == 0    # CSDL rỗng
        t = build_fptree([[1, 2], [1, 2], [1, 2]], 1)              # 3 giao dịch giống nhau
        @test count_nodes(t) == 2 && walk(t, [1, 2]).count == 3
    end
end
