using Printf
include(joinpath(@__DIR__, "exp_common.jl"))

function parse_output_file(filepath::String)
    result = Dict{Set{Int}, Int}()
    open(filepath, "r") do io
        for line in eachline(io)
            parts = split(line, "#SUP:")
            if length(parts) == 2
                items = Set(parse.(Int, split(strip(parts[1]))))
                sup = parse(Int, strip(parts[2]))
                result[items] = sup
            end
        end
    end
    return result
end

function check_discrepancies(name::String, spmf_results::Dict, my_results::Dict)
    spmf_count = length(spmf_results)
    my_count = length(my_results)
    
    exact_matches = 0
    for (itemset, sup) in my_results
        if get(spmf_results, itemset, -1) == sup
            exact_matches += 1
        end
    end
    
    match_ratio = spmf_count == 0 ? 100.0 : (exact_matches / spmf_count) * 100.0
    @printf " - %-4s Itemsets: %d | Exact Matches: %d | Ratio: %.2f%%\n" name my_count exact_matches match_ratio
    return my_count, exact_matches, match_ratio
end

function run_correctness_experiment()
    datasets = [
        ("chess", 0.8),
        ("mushroom", 0.4),
        ("retail", 0.05),
        ("T10I4D100K", 0.01),
        ("accidents", 0.6)
    ]
    
    out_dir = results_dir("exp1_correctness")
    csv_path = joinpath(out_dir, "exp1_correctness.csv")
    my_out_dir = mkpath(joinpath(ROOT, "data", "my_outputs"))
    spmf_out_dir = mkpath(joinpath(ROOT, "data", "spmf_outputs"))
    
    println("="^70)
    println("EXPERIMENT 1: CORRECTNESS EVALUATION (BASE & OPT vs SPMF)")
    println("="^70)

    open(csv_path, "w") do io
        println(io, "Dataset,Minsup,SPMF_Count,Base_Count,Base_Exact,Base_Ratio(%),Opt_Count,Opt_Exact,Opt_Ratio(%)")
        
        for (dataset_name, minsup) in datasets
            @printf "\nProcessing %-12s | Minsup = %.2f\n" dataset_name minsup
            
            db_path = benchmark_path(dataset_name)
            if !isfile(db_path)
                println(" -> [SKIP] Database not found: $db_path")
                continue
            end

            spmf_out = joinpath(spmf_out_dir, "$(dataset_name)_out.txt")
            my_base_out = joinpath(my_out_dir, "$(dataset_name)_base_out.txt")
            my_opt_out = joinpath(my_out_dir, "$(dataset_name)_opt_out.txt")

            try
                run(`$JAVA -jar $SPMF_JAR run FPGrowth_itemsets $db_path $spmf_out $minsup`)
            catch
                println(" -> [ERROR] Failed to run SPMF.")
                continue
            end

            db = read_spmf(db_path)
            min_count = minsup_to_count(minsup, length(db))
            
            write_spmf(my_base_out, fpgrowth(FPTree, db, min_count))
            write_spmf(my_opt_out, fpgrowth(OptFPTree, db, min_count))

            spmf_results = parse_output_file(spmf_out)
            base_results = parse_output_file(my_base_out)
            opt_results  = parse_output_file(my_opt_out)
            
            spmf_count = length(spmf_results)
            @printf " - SPMF Itemsets: %d\n" spmf_count

            base_count, base_exact, base_ratio = check_discrepancies("BASE", spmf_results, base_results)
            opt_count, opt_exact, opt_ratio    = check_discrepancies("OPT ", spmf_results, opt_results)
            
            println(io, join((dataset_name, minsup, spmf_count, base_count, base_exact, base_ratio, opt_count, opt_exact, opt_ratio), ','))
        end
    end
    println("\n" * "="^70)
    println("Report saved to: $csv_path")
end

run_correctness_experiment()