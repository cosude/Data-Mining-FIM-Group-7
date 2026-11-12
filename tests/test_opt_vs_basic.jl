using Test
using Printf

isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

@testset "Optimization Benchmark (Base vs Opt)" begin
    dataset_name = "mushroom"
    minsup = 0.3
    
    db_path = joinpath(@__DIR__, "..", "data", "benchmark", "$(dataset_name).txt")
    
    if !isfile(db_path)
        println("-> [SKIP] Benchmark dataset $(dataset_name).txt not found.")
        @test_skip false
    else
        db = read_spmf(db_path)
        ξ = minsup_to_count(minsup, length(db))
        
        println("\n" * "="^50)
        println("BENCHMARKING: $dataset_name (minsup = $minsup)")
        println("="^50)
        
        # Warm up
        _ = fpgrowth(FPTree, db, ξ)
        _ = fpgrowth(OptFPTree, db, ξ)
        
        # Basic implementation
        GC.gc()
        stats_base = @timed fpgrowth(FPTree, db, ξ)
        
        # Optimized implementation
        GC.gc()
        stats_opt = @timed fpgrowth(OptFPTree, db, ξ)
        
        # Report
        base_mem = stats_base.bytes / (1024^2)
        opt_mem = stats_opt.bytes / (1024^2)
        
        @printf "- Base : %7.3f s | %7.2f MB\n" stats_base.time base_mem
        @printf "- Opt  : %7.3f s | %7.2f MB\n" stats_opt.time opt_mem
        
        println("-"^50)
        speedup = stats_base.time / stats_opt.time
        mem_reduction = base_mem / opt_mem
        
        @printf "=> SPEEDUP          : %.2fx faster\n" speedup
        @printf "=> MEMORY REDUCTION : %.2fx less RAM\n" mem_reduction
        println("="^50)
        
        @test speedup > 0.8
    end
end