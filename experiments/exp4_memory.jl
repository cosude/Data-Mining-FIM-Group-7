# EXPERIMENT 4: BỘ NHỚ (PEAK RAM) - BASE vs OPTIMIZED (+ SPMF tham khảo)
#
# Sys.maxrss() là mức RAM cao nhất của CẢ tiến trình và không bao giờ giảm, nên mỗi lần đo
# phải chạy trong một tiến trình Julia mới. Script có 2 chế độ:
#   julia --project=. experiments/exp4_memory.jl                               -> điều khiển, ghi CSV
#   julia --project=. experiments/exp4_memory.jl --worker <db> <minsup> <impl> -> đo 1 lần, in RESULT
using Printf
include(joinpath(@__DIR__, "exp_common.jl"))

const MB = 1024^2

# Tiến trình con: đo một cấu hình duy nhất rồi in một dòng RESULT
function worker(db_path, minsup, impl)
    T = tree_type(impl)
    db = read_spmf(db_path)
    ξ = minsup_to_count(minsup, length(db))
    warmup()  # biên dịch trước để bộ nhớ của JIT không bị tính vào phép đo
    GC.gc()
    rss0 = Sys.maxrss()                     # baseline: runtime Julia + DB đã nạp
    stats = @timed fpgrowth(T, db, ξ)
    rss1 = Sys.maxrss()                     # đỉnh RAM sau khi khai thác
    n_itemsets = length(stats.value)
    stats = (time = stats.time, bytes = stats.bytes, gctime = stats.gctime)

    tree = fptree_construction(T, db, ξ)    # cây FP ban đầu, để đo riêng cấu trúc dữ liệu
    @printf "RESULT,%.3f,%.3f,%.3f,%.6f,%.6f,%d,%.3f,%d,%.3f\n" rss1/MB (rss1 - rss0)/MB stats.bytes/MB stats.time stats.gctime n_itemsets Base.summarysize(tree)/MB count_nodes(tree) Base.summarysize(db)/MB
end

function run_memory_experiment(; reps = 3)
    # Một minsup "trung bình" cho mỗi bộ (khoảng giữa dải minsup của exp2)
    configs = [
        ("chess", 0.75),
        ("mushroom", 0.35),
        ("retail", 0.04),
        ("T10I4D100K", 0.02),
        ("accidents", 0.65),
    ]
    out_dir = results_dir("exp4_memory")
    csv_path = joinpath(out_dir, "exp4_memory.csv")
    use_spmf = spmf_available()
    script = @__FILE__

    println("="^100)
    println("EXPERIMENT 4: MEMORY USAGE (BASE vs OPT, SPMF tham khảo)  - median của $reps lần, mỗi lần 1 tiến trình")
    println("="^100)

    open(csv_path, "w") do io
        println(io, "Dataset,Minsup,Impl,Peak_RSS_MB,Delta_RSS_MB,Alloc_MB,Time_s,GC_Time_s,Itemsets,Tree_MB,Tree_Nodes,DB_MB,JVM_Heap_MB")
        for (name, minsup) in configs
            db_path = benchmark_path(name)
            if !isfile(db_path)
                println(" -> [SKIP] Database not found: $db_path")
                continue
            end
            for impl in ("base", "opt")
                runs = Vector{Vector{Float64}}()
                for _ in 1:reps
                    cmd = `$(Base.julia_cmd()) --project=$ROOT $script --worker $db_path $minsup $impl`
                    line = filter(startswith("RESULT,"), readlines(cmd))
                    push!(runs, parse.(Float64, split(only(line), ',')[2:end]))
                end
                med = [median(r[k] for r in runs) for k in 1:length(runs[1])]
                peak, delta, alloc, t, gct, nset, tree_mb, nodes, db_mb = med
                @printf " %-11s %5.3f %-4s | peak %8.1f MB | Δ %8.1f MB | alloc %9.1f MB | tree %7.2f MB (%8d nodes) | %7.3fs\n" name minsup impl peak delta alloc tree_mb nodes t
                println(io, join((name, minsup, impl, peak, delta, alloc, t, gct, Int(nset), tree_mb, Int(nodes), db_mb, NaN), ','))
            end
            if use_spmf
                runs = [run_spmf(db_path, minsup) for _ in 1:reps]
                t = median(r[1] for r in runs)
                heap = median(r[2] for r in runs)
                @printf " %-11s %5.3f spmf | JVM heap %7.1f MB | %7.3fs\n" name minsup heap t
                println(io, join((name, minsup, "spmf", NaN, NaN, NaN, t, NaN, runs[end][3], NaN, -1, NaN, heap), ','))
            end
        end
    end
    println("="^100)
    println("Report saved to: $csv_path")
end

if length(ARGS) >= 4 && ARGS[1] == "--worker"
    worker(ARGS[2], parse(Float64, ARGS[3]), ARGS[4])
else
    run_memory_experiment()
end
