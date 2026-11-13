using Printf

isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

function run_runtime_experiment()
    # Define 5-7 minsup for each benchmark in decreasing order
    experiment_configs = [
        ("chess", [0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6]),
        ("mushroom", [0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2]),
        ("retail", [0.1, 0.08, 0.06, 0.04, 0.02, 0.01]),
        ("T10I4D100K", [0.05, 0.04, 0.03, 0.02, 0.015, 0.01]),
        ("accidents", [0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5])
    ]
    
    spmf_jar = joinpath(@__DIR__, "..", "tools", "spmf.jar")
    out_dir = joinpath(@__DIR__, "..", "data", "results", "exp2_runtime_vs_minsup")
    mkpath(out_dir)
    
    csv_path = joinpath(out_dir, "exp2_runtime.csv")
    
    open(csv_path, "w") do io
        println(io, "Dataset,Minsup,SPMF_Time_s,Base_Time_s")
        
        println("="^75)
        println("EXPERIMENT 2: RUNTIME VS MINSUP (SPMF vs BASE)")
        println("="^75)

        print("Warming up JIT compiler... ")
        dummy_db = [[1, 2], [1, 2, 3], [2, 3]]
        fpgrowth(FPTree, dummy_db, 1)
        fpgrowth(OptFPTree, dummy_db, 1)
        println("Done!\n")

        for (dataset_name, minsups) in experiment_configs
            println("-"^75)
            println("Dataset: $dataset_name")
            
            db_path = joinpath(@__DIR__, "..", "data", "benchmark", "$(dataset_name).txt")
            if !isfile(db_path)
                println(" -> [SKIP] Database not found: $db_path")
                continue
            end
            
            db = read_spmf(db_path)
            
            for minsup in minsups
                @printf " Minsup = %5.3f | " minsup
                min_count = minsup_to_count(minsup, length(db))
                
                # Measure runtime
                spmf_out = tempname()
                time_spmf = @elapsed begin
                    try
                        run(pipeline(`java -jar "$spmf_jar" run FPGrowth_itemsets "$db_path" "$spmf_out" $minsup`, stdout=devnull, stderr=devnull))
                    catch
                        println("SPMF Error")
                    end
                end
                
                # Measure basic implementation runtime
                GC.gc()
                time_base = @elapsed fpgrowth(FPTree, db, min_count)
                
                @printf "SPMF: %7.3fs | Base: %7.3fs" time_spmf time_base
                
                println(io, "$dataset_name,$minsup,$time_spmf,$time_base")
            end
        end
    end
    println("="^75)
    println("Report saved to: $csv_path")
end

run_runtime_experiment()