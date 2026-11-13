using Printf

isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

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

function run_correctness_experiment()
    datasets = [
        ("chess", 0.8),
        ("mushroom", 0.4),
        ("retail", 0.05),
        ("T10I4D100K", 0.01),
        ("accidents", 0.6)
    ]
    
    spmf_jar = joinpath(@__DIR__, "..", "tools", "spmf.jar")
    out_dir = joinpath(@__DIR__, "..", "data", "results", "exp1_correctness")
    mkpath(out_dir)
    
    csv_path = joinpath(out_dir, "exp1_correctness.csv")
    
    open(csv_path, "w") do io
        # CSV header row
        println(io, "Dataset,Minsup,SPMF_Count,Group_Base_Count,Exact_Matches,Match_Ratio(%)")
        
        println("="^70)
        println("EXPERIMENT 1: CORRECTNESS EVALUATION (BASE IMPLEMENTATION vs SPMF)")
        println("="^70)

        for (dataset_name, minsup) in datasets
            @printf "\nProcessing %-12s | Minsup = %.2f\n" dataset_name minsup
            
            db_path = joinpath(@__DIR__, "..", "data", "benchmark", "$(dataset_name).txt")
            spmf_out = joinpath(@__DIR__, "..", "data", "spmf_outputs", "$(dataset_name)_out.txt")
            my_out = joinpath(@__DIR__, "..", "data", "my_outputs", "$(dataset_name)_base_out.txt")
            
            mkpath(dirname(spmf_out))
            mkpath(dirname(my_out))

            if !isfile(db_path)
                println(" -> [SKIP] Database not found: $db_path")
                continue
            end

            # Run SPMF
            try
                run(`java -jar "$spmf_jar" run FPGrowth_itemsets "$db_path" "$spmf_out" $minsup`)
            catch
                println(" -> [ERROR] Failed to run SPMF.")
                continue
            end

            # Run basic implementation
            db = read_spmf(db_path)
            min_count = minsup_to_count(minsup, length(db))
            
            itemsets = fpgrowth(FPTree, db, min_count)
            write_spmf(my_out, itemsets)

            # Checking results
            spmf_results = parse_output_file(spmf_out)
            my_results = parse_output_file(my_out)
            
            spmf_count = length(spmf_results)
            my_count = length(my_results)
            
            exact_matches = 0
            mismatches = 0
            
            for (itemset, sup) in my_results
                if haskey(spmf_results, itemset) && spmf_results[itemset] == sup
                    exact_matches += 1
                else
                    mismatches += 1
                end
            end
            
            # Calculate matching percentage
            match_ratio = spmf_count == 0 ? 100.0 : (exact_matches / spmf_count) * 100.0
            
            # Write to CSV
            println(io, "$dataset_name,$minsup,$spmf_count,$my_count,$exact_matches,$match_ratio")
            
            # Logging
            @printf " - SPMF Itemsets : %d\n" spmf_count
            @printf " - Group Itemsets: %d\n" my_count
            @printf " - Exact Matches : %d\n" exact_matches
            @printf " -> MATCH RATIO  : %.2f%%\n" match_ratio
            
            # Tracing mismatches
            if match_ratio < 100.0 || my_count != spmf_count
                println(" [!] DISCREPANCY DETECTED! Analyzing missing/extra itemsets...")
                
                # Finding frequent itemsets basic implementation did not produce
                missing_in_my = setdiff(keys(spmf_results), keys(my_results))
                if !isempty(missing_in_my)
                    println("     + Missing from Group's Output: ", length(missing_in_my), " itemsets.")
                end
                
                # Finding non-frequent itemsets basic implementation produced
                extra_in_my = setdiff(keys(my_results), keys(spmf_results))
                if !isempty(extra_in_my)
                    println("     + Extra in Group's Output: ", length(extra_in_my), " itemsets.")
                end
                
                # Finding matched frequent itemsets but mismatched support count
                wrong_sup = 0
                for k in intersect(keys(spmf_results), keys(my_results))
                    if spmf_results[k] != my_results[k]
                        wrong_sup += 1
                    end
                end
                if wrong_sup > 0
                    println("     + Itemsets with Wrong Support: ", wrong_sup, " itemsets.")
                end
            end
        end
    end
    println("\n" * "="^70)
    println("Report saved to: $csv_path")
end

run_correctness_experiment()