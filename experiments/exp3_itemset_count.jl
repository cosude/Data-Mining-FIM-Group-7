using Printf

isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

function run_itemset_count_experiment()
    experiment_configs = [
        ("chess",       [0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65]), # Dense
        ("mushroom",    [0.6, 0.5, 0.4, 0.35, 0.3, 0.25, 0.2]),   # Dense
        ("accidents",   [0.9, 0.8, 0.7, 0.6, 0.5, 0.4]),          # Dense
        ("retail",      [0.1, 0.08, 0.06, 0.04, 0.02, 0.01]),     # Sparse
        ("T10I4D100K",  [0.05, 0.04, 0.03, 0.02, 0.01, 0.005])    # Sparse
    ]
    
    out_dir = joinpath(@__DIR__, "..", "data", "results", "exp3_itemset_count")
    mkpath(out_dir)
    csv_path = joinpath(out_dir, "exp3_itemset_counts.csv")
    
    open(csv_path, "w") do io
        println(io, "Dataset,Type,Minsup,Itemset_Count")
        
        println("="^60)
        println("EXPERIMENT 3: FREQUENT ITEMSET COUNT VS MINSUP")
        println("="^60)

        for (dataset_name, minsups) in experiment_configs
            ds_type = dataset_name in ["chess", "mushroom", "accidents"] ? "Dense" : "Sparse"
            println("\nDataset: $dataset_name ($ds_type)")
            
            db_path = joinpath(@__DIR__, "..", "data", "benchmark", "$(dataset_name).txt")
            if !isfile(db_path)
                println(" -> [SKIP] Database not found: $db_path")
                continue
            end
            
            db = read_spmf(db_path)
            
            for minsup in minsups
                min_count = minsup_to_count(minsup, length(db))
                
                itemsets = fpgrowth(FPTree, db, min_count)
                count = length(itemsets)
                
                @printf " - Minsup = %5.3f | Output Size: %10d itemsets\n" minsup count
                println(io, "$dataset_name,$ds_type,$minsup,$count")
            end
        end
    end
    println("\n" * "="^60)
    println("Report saved to: $csv_path")
end

run_itemset_count_experiment()