using Printf

include(joinpath(@__DIR__, "exp_common.jl"))

function run_runtime_experiment(; reps = 3)
    # Define minsup for each benchmark in decreasing order
    experiment_configs = [
        ("chess", [0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6]),
        ("mushroom", [0.5, 0.45, 0.4, 0.35, 0.3, 0.25, 0.2]),
        ("retail", [0.1, 0.08, 0.06, 0.04, 0.02, 0.01]),
        ("T10I4D100K", [0.05, 0.04, 0.03, 0.02, 0.015, 0.01]),
        ("accidents", [0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5])
    ]
    
    out_dir = results_dir("exp2_runtime_vs_minsup")
    csv_path = joinpath(out_dir, "exp2_runtime.csv")
    use_spmf = spmf_available()
    
    println("="^85)
    println("EXPERIMENT 2: RUNTIME VS MINSUP (SPMF vs BASE vs OPT)")
    println("="^85)

    print("Warming up JIT compiler... ")
    warmup()
    println("Done!\n")

    open(csv_path, "w") do io
        println(io, "Dataset,Minsup,SPMF_Time_s,Base_Time_s,Opt_Time_s")
        
        for (dataset_name, minsups) in experiment_configs
            println("-"^85)
            println("Dataset: $dataset_name")
            
            db_path = benchmark_path(dataset_name)
            if !isfile(db_path)
                println(" -> [SKIP] Database not found: $db_path")
                continue
            end
            
            db = read_spmf(db_path)
            
            for minsup in minsups
                @printf " Minsup = %5.3f | " minsup
                min_count = minsup_to_count(minsup, length(db))
                
                # Measure SPMF runtime
                t_spmf = use_spmf ? median(run_spmf(db_path, minsup)[1] for _ in 1:reps) : NaN
                
                # Measure Base runtime
                t_base, _ = median_time(() -> fpgrowth(FPTree, db, min_count), reps)

                # Measure Opt runtime
                t_opt, _ = median_time(() -> fpgrowth(OptFPTree, db, min_count), reps)
                
                @printf "SPMF: %7.3fs | Base: %7.3fs | Opt: %7.3fs\n" t_spmf t_base t_opt
                
                println(io, join((dataset_name, minsup, t_spmf, t_base, t_opt), ','))
            end
        end
    end
    println("="^85)
    println("Report saved to: $csv_path")
end

run_runtime_experiment()