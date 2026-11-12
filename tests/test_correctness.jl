using Test, Random
isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

# Kết quả dạng Dict(itemset đã sắp => support); báo lỗi nếu một itemset bị sinh hai lần.
function as_dict(patterns)
    d = Dict{Vector{Int},Int}()
    for (items, sup) in patterns
        key = sort(items)
        @test !haskey(d, key)
        d[key] = sup
    end
    return d
end

# Brute-force: duyệt mọi tập con của các item, đếm support trực tiếp trên DB.
function brute_force(DB::Vector{Vector{Int}}, ξ::Int)
    items = sort(unique(reduce(vcat, DB; init = Int[])))
    res = Dict{Vector{Int},Int}()
    for mask in 1:(2^length(items) - 1)
        s = [items[j] for j in eachindex(items) if mask & (1 << (j - 1)) != 0]
        sup = count(t -> all(in(t), s), DB)
        sup >= ξ && (res[s] = sup)
    end
    return res
end

@testset "FP-growth: Example 2 / Table 2 của bài báo" begin
    DB = read_spmf(joinpath(@__DIR__, "..", "data", "toy", "han2000.txt"))
    a, b, c, f, m, p = 1, 2, 3, 6, 13, 16
    expected = Dict(sort(k) => v for (k, v) in [
        [f] => 4, [c] => 4, [a] => 3, [b] => 3, [m] => 3, [p] => 3,
        [c, p] => 3,
        [a, m] => 3, [c, m] => 3, [f, m] => 3, [c, a, m] => 3, [f, a, m] => 3, [f, c, m] => 3, [f, c, a, m] => 3,
        [f, a] => 3, [c, a] => 3, [f, c, a] => 3,
        [f, c] => 3,
    ])
    @test as_dict(fpgrowth(DB, 3)) == expected
    @test as_dict(fpgrowth(DB, 2)) == brute_force(DB, 2)
end

@testset "FP-growth: single prefix-path (Example 3, Lemma 3.3)" begin
    a, b, c, d, e, f = 1:6
    # Cây: (a:10) → (b:8) → (c:7), rồi c rẽ nhánh thành (d:4 → f:3) và (e:3), như Hình 4(a)
    DB = vcat(fill([a, b, c, d, f], 3), [[a, b, c, d]], fill([a, b, c, e], 3), [[a, b]], fill([a], 2))
    tree = fptree_construction(DB, 3)
    P, R = FPGrowth.single_prefix_path(tree)
    @test [n.item_name for n in P] == [a, b, c] && [n.count for n in P] == [10, 8, 7]
    @test length(R.children) == 2

    result = as_dict(fpgrowth(tree, 3))
    @test result == brute_force(DB, 3)
    # freq_pattern_set(P) = 7, freq_pattern_set(Q) = {d:4, e:3, f:3, df:3}, P × Q = 7 × 4
    @test length(result) == 7 + 4 + 7 * 4
    @test result[[a, d]] == 4 && result[[a, b, c, d, f]] == 3
end

@testset "FP-growth: trường hợp biên" begin
    @test isempty(fpgrowth(Vector{Int}[], 1))
    @test isempty(fpgrowth([[1, 2], [3]], 2))                 # không item nào phổ biến
    @test as_dict(fpgrowth([[1, 2, 3], [1, 2, 3]], 2)) ==       # cây chỉ là một đường đơn
          brute_force([[1, 2, 3], [1, 2, 3]], 2)
end

@testset "FP-growth: so với brute-force trên CSDL ngẫu nhiên" begin
    rng = MersenneTwister(2026)
    for trial in 1:20
        DB = [unique(rand(rng, 1:12, rand(rng, 1:8))) for _ in 1:rand(rng, 1:60)]
        for ξ in (1, 2, 5)
            @test as_dict(fpgrowth(DB, ξ)) == brute_force(DB, ξ)
        end
    end
end
