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
        min_count = minsup_to_count(minsup, length(db))
        
        println("\n" * "="^50)
        println("BENCHMARKING: $dataset_name (minsup = $minsup)")
        println("="^50)
        
        _ = mine_fpgrowth(fptree_construction(FPTree, db, min_count), min_count)
        _ = mine_fpgrowth(fptree_construction(OptFPTree, db, min_count), min_count)
        
        # Base implementation
        GC.gc()
        stats_base = @timed begin
            tree_base = fptree_construction(FPTree, db, min_count)
            mine_fpgrowth(tree_base, min_count)
        end
        
        # Optimized implementation
        GC.gc()
        stats_opt = @timed begin
            tree_opt = fptree_construction(OptFPTree, db, min_count)
            mine_fpgrowth(tree_opt, min_count)
        end
        
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