# Tiện ích dùng chung cho exp4, exp5, exp6.

isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SPMF_JAR = joinpath(ROOT, "tools", "spmf.jar")
# spmf.jar cần Java >= 25. Nếu `java` mặc định cũ hơn, đặt biến môi trường SPMF_JAVA
# trỏ tới java.exe của JDK 25.
const JAVA = get(ENV, "SPMF_JAVA", "java")

benchmark_path(name) = joinpath(ROOT, "data", "benchmark", "$(name).txt")
results_dir(name) = mkpath(joinpath(ROOT, "data", "results", name))

function median(xs)
    s = sort(collect(xs))
    n = length(s)
    return isodd(n) ? s[(n + 1) ÷ 2] : (s[n ÷ 2] + s[n ÷ 2 + 1]) / 2
end

"""
    run_spmf(db_path, minsup) -> (time_s, mem_mb, count)

Chạy FPGrowth_itemsets của SPMF và đọc phần STATS mà SPMF tự in ra. Thời gian là
`Total time` do SPMF đo bên trong (không tính thời gian khởi động JVM). Trả về
`(NaN, NaN, -1)` nếu không chạy được SPMF.
"""
function run_spmf(db_path, minsup)
    out = tempname()
    buf = IOBuffer()
    try
        run(pipeline(`$JAVA -jar $SPMF_JAR run FPGrowth_itemsets $db_path $out $minsup`; stdout = buf, stderr = devnull))
    catch
        return (NaN, NaN, -1)
    finally
        rm(out; force = true)
    end
    s = String(take!(buf))
    t = match(r"Total time ~\s*([\d.]+)\s*ms", s)
    m = match(r"Max memory usage:\s*([\d.]+)", s)
    c = match(r"Frequent itemsets count\s*:\s*(\d+)", s)
    return (t === nothing ? NaN : parse(Float64, t[1]) / 1000,
            m === nothing ? NaN : parse(Float64, m[1]),
            c === nothing ? -1 : parse(Int, c[1]))
end

# Kiểm tra một lần xem máy có chạy được SPMF không.
function spmf_available()
    isfile(SPMF_JAR) || return false
    toy = joinpath(ROOT, "data", "toy", "han2000.txt")
    ok = run_spmf(toy, 0.6)[3] >= 0
    ok || println(" [WARN] Không chạy được SPMF (spmf.jar cần Java >= 25; đặt SPMF_JAVA nếu cần). Cột SPMF sẽ là NaN.")
    return ok
end

# Chạy f() `reps` lần, trả về (thời gian trung vị, kết quả lần cuối).
function median_time(f, reps)
    times = Float64[]
    result = nothing
    for _ in 1:reps
        GC.gc()
        t = @elapsed (result = f())
        push!(times, t)
    end
    return median(times), result
end

function warmup()
    dummy = [[1, 2], [1, 2, 3], [2, 3]]
    fpgrowth(FPTree, dummy, 1)
    fpgrowth(OptFPTree, dummy, 1)
    count_nodes(fptree_construction(FPTree, dummy, 1))
    count_nodes(fptree_construction(OptFPTree, dummy, 1))
    return nothing
end

tree_type(impl) = impl == "base" ? FPTree : OptFPTree
