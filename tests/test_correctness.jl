using Test
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

@testset "Correctness vs SPMF" begin
    datasets = [
        ("chess", 0.8),
        ("mushroom", 0.4),
        ("retail", 0.05),
        ("T10I4D100K", 0.01),
        ("accidents", 0.6)
    ]

    spmf_jar = joinpath(@__DIR__, "..", "tools", "spmf.jar")
    isfile(spmf_jar) || error("[ERROR] spmf.jar not found at: $spmf_jar")

    println("\n" * "="^65)
    println("CORRECTNESS VERIFICATION (Basic & Optimized vs SPMF)")
    println("="^65)

    passed = 0
    for (dataset_name, minsup) in datasets
        db_path    = joinpath(@__DIR__, "..", "data", "benchmark", "$(dataset_name).txt")
        spmf_out   = joinpath(@__DIR__, "..", "data", "spmf_outputs", "$(dataset_name)_out.txt")
        my_out     = joinpath(@__DIR__, "..", "data", "my_outputs", "$(dataset_name)_out.txt")
        my_opt_out = joinpath(@__DIR__, "..", "data", "my_opt_outputs", "$(dataset_name)_out.txt")

        mkpath(dirname(spmf_out))
        mkpath(dirname(my_out))
        mkpath(dirname(my_opt_out))

        if !isfile(db_path)
            println("[SKIP] $dataset_name (minsup=$minsup) — file not found: $db_path")
            @test_skip false
            continue
        end

        try
            run(pipeline(`java -jar "$spmf_jar" run FPGrowth_itemsets "$db_path" "$spmf_out" $minsup`,
                         stdout=devnull, stderr=devnull))
            db = read_spmf(db_path)
            ξ = minsup_to_count(minsup, length(db))

            write_spmf(my_out, fpgrowth(FPTree, db, ξ))
            write_spmf(my_opt_out, fpgrowth(OptFPTree, db, ξ))
        catch e
            println("[FAIL] $dataset_name (minsup=$minsup) — exception: ", sprint(showerror, e))
            @test false
            continue
        end

        spmf_res   = parse_output_file(spmf_out)
        base_res   = parse_output_file(my_out)
        opt_res    = parse_output_file(my_opt_out)
        is_matched = (spmf_res == base_res) && (spmf_res == opt_res)

        status = is_matched ? "PASS" : "FAIL"
        @printf "[%s] %-12s (minsup=%-4.2f) | SPMF: %6d | Basic: %6d | Opt: %6d\n" status dataset_name minsup length(spmf_res) length(base_res) length(opt_res)

        is_matched && (passed += 1)
        @test is_matched
    end

    println("-"^65)
    println("SUMMARY: $passed / $(length(datasets)) datasets 100% matched SPMF.")
    println("="^65)
end