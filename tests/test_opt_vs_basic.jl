using Test
using Printf

isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

@testset "Optimization Benchmark (Basic vs Optimized)" begin
    dataset_name = "mushroom"
    minsup = 0.3
    db_path = joinpath(@__DIR__, "..", "data", "benchmark", "$(dataset_name).txt")

    println("\n" * "="^65)
    println("OPTIMIZATION BENCHMARK ($dataset_name, minsup=$minsup)")
    println("="^65)

    if !isfile(db_path)
        println("[SKIP] $dataset_name — file not found: $db_path")
        println("="^65)
        @test_skip false
    else
        db = read_spmf(db_path)
        ξ = minsup_to_count(minsup, length(db))

        # Warmup JIT
        _ = fpgrowth(FPTree, db, ξ)
        _ = fpgrowth(OptFPTree, db, ξ)

        GC.gc()
        stats_base = @timed fpgrowth(FPTree, db, ξ)
        GC.gc()
        stats_opt = @timed fpgrowth(OptFPTree, db, ξ)

        base_mem = stats_base.bytes / (1024^2)
        opt_mem  = stats_opt.bytes / (1024^2)
        speedup  = stats_base.time / stats_opt.time
        mem_red  = base_mem / opt_mem

        @printf "[INFO] Basic     | %7.3f s | %7.2f MB allocated\n" stats_base.time base_mem
        @printf "[INFO] Optimized | %7.3f s | %7.2f MB allocated\n" stats_opt.time opt_mem
        println("-"^65)
        @printf "SUMMARY: Speedup = %.2fx | Memory reduction = %.2fx\n" speedup mem_red
        println("="^65)

        @test speedup > 0.8
    end
end