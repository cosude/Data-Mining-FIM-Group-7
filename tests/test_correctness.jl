using Test
isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

# Function for parsing output files for comparison
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

@testset "Testing: Correctness vs SPMF" begin
    # dataset name - minsup
    datasets = [
        ("chess", 0.8),
        ("mushroom", 0.4),
        ("retail", 0.05),
        ("T10I4D100K", 0.01),
        ("accidents", 0.6)
    ]
    
    # spmf.jar is in ..\tools\
    spmf_jar = joinpath(@__DIR__, "..", "tools", "spmf.jar")
    isfile(spmf_jar) || error("[ERROR] spmf.jar not found at: $spmf_jar")

    total_datasets = length(datasets)
    correct_datasets = 0

    for (dataset_name, minsup) in datasets
        println("\nProcessing Dataset: $dataset_name (minsup=$minsup)")
        
        # input - output file paths
        db_path = joinpath(@__DIR__, "..", "data", "benchmark", "$(dataset_name).txt")
        spmf_out = joinpath(@__DIR__, "..", "data", "spmf_outputs", "$(dataset_name)_out.txt")
        my_out = joinpath(@__DIR__, "..", "data", "my_outputs", "$(dataset_name)_out.txt")
        my_opt_out = joinpath(@__DIR__, "..", "data", "my_opt_outputs", "$(dataset_name)_out.txt")

        mkpath(dirname(spmf_out))
        mkpath(dirname(my_out))
        mkpath(dirname(my_opt_out))
        
        # Run SMPF
        if !isfile(db_path)
            println(" -> [ERROR] Database file not found at: $db_path")
            println("    Please download $(dataset_name).txt and place it in the benchmark directory.")
            @test false
            continue
        end

        try
            # Execute spmf.jar
            run(`java -jar "$spmf_jar" run FPGrowth_itemsets "$db_path" "$spmf_out" $minsup`)
        catch e
            println(" -> [ERROR] Failed to execute Java/SPMF process.")
            println("    Julia Error Details: ")
            showerror(stdout, e)
            println()
            @test false
            continue
        end
        
        # Run project's implementation
            # Basic implementation
        try
            db = read_spmf(db_path)
            min_count = minsup_to_count(minsup, length(db))
            
            tree = fptree_construction(FPTree, db, min_count)
            itemsets = mine_fpgrowth(tree, min_count)
            
            write_spmf(my_out, itemsets)
        catch e
            println(" -> [ERROR] Group's algorithm threw an exception.")
            showerror(stdout, e)
            println()
            @test false
            continue
        end

            # Optimized implementation
        try
            db = read_spmf(db_path)
            min_count = minsup_to_count(minsup, length(db))
            
            tree = fptree_construction(OptFPTree, db, min_count)
            itemsets = mine_fpgrowth(tree, min_count)
            
            write_spmf(my_opt_out, itemsets)
        catch e
            println(" -> [ERROR] Group's optimized algorithm threw an exception.")
            showerror(stdout, e)
            println()
            @test false
            continue
        end

        # Parse outputs and compare
        spmf_results = parse_output_file(spmf_out)
        my_results = parse_output_file(my_out)
        my_opt_results = parse_output_file(my_opt_out)

        match_count = 0
        match_opt_count = 0

        for (itemset, sup) in my_results
            if haskey(spmf_results, itemset) && spmf_results[itemset] == sup
                match_count += 1
            end
        end

        for (itemset, sup) in my_opt_results
            if haskey(spmf_results, itemset) && spmf_results[itemset] == sup
                match_opt_count += 1
            end
        end
        
        expected_len = length(spmf_results)
        actual_len = length(my_results)
        actual_opt_len = length(my_opt)
        
        println(" - SPMF generated:  $expected_len itemsets")
        println(" - Group generated: $actual_len itemsets")
        println(" - Group optimized generated: $actual_len itemsets")
        
        if expected_len == actual_len && expected_len == actual_opt_len && match_count == expected_len && match_opt_count == expected_len
            println(" -> RESULT: 100% Match (PASSED)")
            correct_datasets += 1
            @test true
        else
            println(" -> RESULT: Mismatch Detected (FAILED)")
            @test false
        end
    end
    
    println("\n" * "="^50)
    println("FINAL REPORT: $correct_datasets / $total_datasets datasets perfectly matched SPMF.")
    println("="^50)
end