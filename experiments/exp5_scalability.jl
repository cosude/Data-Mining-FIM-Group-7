# EXPERIMENT 5: KHẢ NĂNG MỞ RỘNG - thời gian theo số giao dịch (10/25/50/75/100%)
#
# Xáo CSDL một lần với seed cố định rồi lấy k% đầu: tập nhỏ luôn nằm trong tập lớn, và kết quả
# không phụ thuộc thứ tự gốc của file. Giữ cố định minsup TƯƠNG ĐỐI (như Fig. 13 của bài báo).
# Không nhân bản giao dịch để tạo CSDL lớn: cây FP sẽ không lớn thêm (bài báo, mục 5.4).
using Printf, Random
include(joinpath(@__DIR__, "exp_common.jl"))

function write_subset(path, db)
    open(path, "w") do io
        for t in db
            join(io, t, ' ')
            println(io)
        end
    end
    return path
end

# Bình phương tối thiểu t = a*n + b, trả về (a, b, R²)
function linear_fit(x, y)
    x̄, ȳ = sum(x) / length(x), sum(y) / length(y)
    a = sum((x .- x̄) .* (y .- ȳ)) / sum((x .- x̄) .^ 2)
    b = ȳ - a * x̄
    r2 = 1 - sum((y .- (a .* x .+ b)) .^ 2) / sum((y .- ȳ) .^ 2)
    return a, b, r2
end

function run_scalability_experiment(; reps = 3)
    configs = [
        ("accidents", 0.5),   # dày, 340k giao dịch
        ("retail", 0.005),    # thưa, 88k giao dịch
    ]
    fractions = [0.10, 0.25, 0.50, 0.75, 1.00]

    out_dir = results_dir("exp5_scalability")
    subset_dir = mkpath(joinpath(ROOT, "data", "benchmark", "subsets"))
    csv_path = joinpath(out_dir, "exp5_scalability.csv")
    use_spmf = spmf_available()

    println("="^100)
    println("EXPERIMENT 5: SCALABILITY (runtime vs #transactions)  - median của $reps lần")
    println("="^100)
    print("Warming up JIT compiler... ")
    warmup()
    println("Done!")

    open(csv_path, "w") do io
        println(io, "Dataset,Minsup,Fraction,Transactions,Min_Count,Base_Build_s,Base_Time_s,Opt_Time_s,SPMF_Time_s,Itemsets,Tree_Nodes")
        for (name, minsup) in configs
            db_path = benchmark_path(name)
            if !isfile(db_path)
                println(" -> [SKIP] Database not found: $db_path")
                continue
            end
            println("-"^100)
            println("Dataset: $name (minsup = $minsup)")
            full = shuffle(MersenneTwister(42), read_spmf(db_path))

            ns, base_times = Int[], Float64[]
            for frac in fractions
                n = round(Int, frac * length(full))
                db = full[1:n]
                ξ = minsup_to_count(minsup, n)
                sub_path = write_subset(joinpath(subset_dir, "$(name)_$(round(Int, 100frac)).txt"), db)

                t_build, tree = median_time(() -> fptree_construction(FPTree, db, ξ), reps)
                t_base, itemsets = median_time(() -> fpgrowth(FPTree, db, ξ), reps)
                t_opt, _ = median_time(() -> fpgrowth(OptFPTree, db, ξ), reps)
                t_spmf = use_spmf ? median(run_spmf(sub_path, minsup)[1] for _ in 1:reps) : NaN

                @printf " %3d%% | n = %7d | build %7.3fs | base %7.3fs | opt %7.3fs | spmf %7.3fs | %7d itemsets | %8d nodes\n" round(Int, 100frac) n t_build t_base t_opt t_spmf length(itemsets) count_nodes(tree)
                println(io, join((name, minsup, frac, n, ξ, t_build, t_base, t_opt, t_spmf, length(itemsets), count_nodes(tree)), ','))
                push!(ns, n); push!(base_times, t_base)
            end
            a, b, r2 = linear_fit(ns, base_times)
            @printf " Linear fit (base): t ≈ %.3e * n + %.3f   (R² = %.4f)\n" a b r2
        end
    end
    println("="^100)
    println("Report saved to: $csv_path")
end

run_scalability_experiment()
