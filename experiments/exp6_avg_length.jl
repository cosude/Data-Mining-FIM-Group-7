# EXPERIMENT 6: ẢNH HƯỞNG CỦA ĐỘ DÀI GIAO DỊCH TRUNG BÌNH
#
# Sinh CSDL tổng hợp theo kiểu IBM Quest (Agrawal & Srikant 1994), loại dữ liệu bài báo dùng
# (T10I4D100K, T25I20D10K): có một kho "pattern tiềm năng", mỗi giao dịch ghép từ vài pattern
# trong kho. Chỉ thay đổi T (độ dài trung bình), mọi tham số khác và seed giữ nguyên.
using Printf, Random
include(joinpath(@__DIR__, "exp_common.jl"))

# Poisson(λ) theo thuật toán Knuth (đủ dùng với λ <= 30)
function poisson(rng, λ)
    L, k, p = exp(-λ), 0, 1.0
    while true
        p *= rand(rng)
        p <= L && return k
        k += 1
    end
end

"""
    generate_quest(rng; ntrans, avg_len, nitems, npats, avg_pat_len, corr)

Bản rút gọn của bộ sinh IBM Quest:
- kho `npats` pattern, độ dài ~ Poisson(`avg_pat_len`), một phần item lấy lại từ pattern
  trước đó (tỉ lệ `corr`) để các pattern có liên quan với nhau;
- mỗi pattern có trọng số ~ Exp(1) (pattern hay gặp / ít gặp) và mức "corruption" ~ N(0.5, 0.1):
  khi đưa vào giao dịch, pattern bị bỏ bớt item với xác suất đó;
- độ dài giao dịch ~ Poisson(`avg_len`); giao dịch được ghép các pattern cho tới khi đủ dài.
"""
function generate_quest(rng; ntrans, avg_len, nitems = 1000, npats = 500, avg_pat_len = 4, corr = 0.5)
    pats = Vector{Vector{Int}}()
    prev = Int[]
    for _ in 1:npats
        len = max(1, poisson(rng, avg_pat_len))
        p = Set{Int}(shuffle(rng, prev)[1:min(length(prev), round(Int, corr * len))])
        while length(p) < len
            push!(p, rand(rng, 1:nitems))
        end
        prev = collect(p)
        push!(pats, prev)
    end
    cw = cumsum(-log.(rand(rng, npats)))
    cw ./= cw[end]
    corruption = clamp.(0.5 .+ 0.1 .* randn(rng, npats), 0.0, 0.9)

    db = Vector{Vector{Int}}()
    for _ in 1:ntrans
        len = max(1, poisson(rng, avg_len))
        t = Set{Int}()
        while length(t) < len
            k = min(searchsortedfirst(cw, rand(rng)), npats)
            items = copy(pats[k])
            while !isempty(items) && rand(rng) < corruption[k]
                deleteat!(items, rand(rng, 1:length(items)))
            end
            # Pattern làm giao dịch dài quá: một nửa số lần vẫn thêm vào, nửa còn lại dừng
            length(t) + length(items) > len && !isempty(t) && rand(rng) < 0.5 && break
            union!(t, items)
        end
        push!(db, sort!(collect(t)))
    end
    return db
end

function run_avg_length_experiment(; reps = 3, ntrans = 10_000, minsup = 0.01, time_limit = 120.0)
    avg_lens = [5, 10, 15, 20, 25, 30]

    out_dir = results_dir("exp6_avg_length")
    synth_dir = mkpath(joinpath(ROOT, "data", "benchmark", "synthetic"))
    csv_path = joinpath(out_dir, "exp6_avg_length.csv")
    use_spmf = spmf_available()

    println("="^110)
    println("EXPERIMENT 6: AVERAGE TRANSACTION LENGTH  (D = $ntrans, I = 4, |items| = 1000, minsup = $minsup) - median của $reps lần")
    println("="^110)
    print("Warming up JIT compiler... ")
    warmup()
    println("Done!")

    open(csv_path, "w") do io
        println(io, "T_Param,Actual_Avg_Len,Max_Len,Transactions,Minsup,Frequent_Items,Base_Build_s,Base_Time_s,Opt_Time_s,SPMF_Time_s,Itemsets,Max_Itemset_Len,Tree_Nodes")
        for T in avg_lens
            db = generate_quest(MersenneTwister(2024); ntrans = ntrans, avg_len = T)
            path = joinpath(synth_dir, "T$(T)I4D$(ntrans ÷ 1000)K.txt")
            open(path, "w") do f
                for t in db
                    join(f, t, ' ')
                    println(f)
                end
            end
            ξ = minsup_to_count(minsup, length(db))
            actual_len = sum(length, db) / length(db)
            n_freq = length(build_flist(count_supports(db), ξ))

            t_build, tree = median_time(() -> fptree_construction(FPTree, db, ξ), reps)
            t_base, itemsets = median_time(() -> fpgrowth(FPTree, db, ξ), reps)
            t_opt, _ = median_time(() -> fpgrowth(OptFPTree, db, ξ), reps)
            t_spmf = use_spmf ? median(run_spmf(path, minsup)[1] for _ in 1:reps) : NaN
            max_set = maximum(length(first(x)) for x in itemsets; init = 0)

            @printf " T = %2d (thực tế %5.2f) | %4d freq items | build %6.3fs | base %7.3fs | opt %7.3fs | spmf %7.3fs | %9d itemsets (dài nhất %2d) | %8d nodes\n" T actual_len n_freq t_build t_base t_opt t_spmf length(itemsets) max_set count_nodes(tree)
            println(io, join((T, actual_len, maximum(length, db), length(db), minsup, n_freq, t_build, t_base, t_opt, t_spmf, length(itemsets), max_set, count_nodes(tree)), ','))
            flush(io)

            if t_base > time_limit
                println(" -> Dừng: base đã quá $(time_limit)s, các T lớn hơn sẽ còn lâu hơn.")
                break
            end
        end
    end
    println("="^110)
    println("Report saved to: $csv_path")
end

run_avg_length_experiment()
