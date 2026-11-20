using Printf
using Combinatorics
using ArgParse

include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--minsup", "-s"
            help = "Minimum support (relative in (0, 1] or absolute integer count > 1)"
            arg_type = Float64
            default = 0.01
        "--minconf", "-c"
            help = "Minimum confidence in [0, 1]"
            arg_type = Float64
            default = 0.2
        "--top", "-k"
            help = "Number of top rules to display"
            arg_type = Int
            default = 10
    end
    return parse_args(s)
end

function load_mapping(filepath::String)
    mapping = Dict{Int, String}()
    lines = readlines(filepath)[2:end]
    for line in lines
        parts = split(strip(line), ",")
        if length(parts) == 2
            mapping[parse(Int, parts[1])] = String(parts[2])
        end
    end
    return mapping
end

function generate_association_rules(itemsets, total_trans, minconf)
    rules = []
    support_dict = Dict(Set(itemset) => sup for (itemset, sup) in itemsets)
    
    for (itemset, sup_XY) in itemsets
        length(itemset) < 2 && continue
        
        for i in 1:(length(itemset) - 1)
            for X_tuple in combinations(itemset, i)
                X = Set(X_tuple)
                Y = setdiff(Set(itemset), X)
                
                sup_X = get(support_dict, X, 0)
                if sup_X > 0
                    conf = sup_XY / sup_X
                    if conf >= minconf
                        sup_Y = get(support_dict, Y, 0)
                        prob_Y = sup_Y / total_trans
                        lift = conf / prob_Y
                        push!(rules, (X, Y, sup_XY, conf, lift))
                    end
                end
            end
        end
    end
    sort!(rules, by = x -> x[5], rev = true)
    return rules
end

function main()
    args = parse_commandline()
    minsup_arg = args["minsup"]
    minconf    = args["minconf"]
    top_k      = args["top"]

    root_dir = joinpath(@__DIR__, "..")
    data_dir = joinpath(root_dir, "data", "market_basket")
    out_dir  = joinpath(root_dir, "data", "results", "app1_market_basket")
    mkpath(out_dir)

    println("Mining frequent itemsets (minsup = $minsup_arg, minconf = $minconf)...")
    db = read_spmf(joinpath(data_dir, "encoded_groceries.txt"))
    mapping = load_mapping(joinpath(data_dir, "mapping.csv"))
    total_trans = length(db)
    
    minsup_count = minsup_arg <= 1.0 ? minsup_to_count(minsup_arg, total_trans) : round(Int, minsup_arg)
    itemsets = fpgrowth(OptFPTree, db, minsup_count)
    rules = generate_association_rules(itemsets, total_trans, minconf)
    
    # Print Top K to terminal
    k = min(top_k, length(rules))
    println("\n--- TOP $k ASSOCIATION RULES (Based on Lift) ---")
    @printf "%-50s | %-8s | %-8s | %-6s\n" "Rule (X -> Y)" "Support" "Conf(%)" "Lift"
    println("-"^80)
    
    for i in 1:k
        X, Y, sup, conf, lift = rules[i]
        str_X = join(sort([mapping[item] for item in X]), ", ")
        str_Y = join(sort([mapping[item] for item in Y]), ", ")
        rule_str = "{$str_X} => {$str_Y}"
        @printf "%-50s | %-8d | %-8.2f | %-6.2f\n" rule_str sup (conf * 100) lift
    end

    # Save all rules to CSV
    out_csv = joinpath(out_dir, "association_rules.csv")
    open(out_csv, "w") do io
        println(io, "Antecedent,Consequent,Support,Confidence_Pct,Lift")
        for (X, Y, sup, conf, lift) in rules
            str_X = join(sort([mapping[item] for item in X]), ", ")
            str_Y = join(sort([mapping[item] for item in Y]), ", ")
            @printf io "\"{%s}\",\"{%s}\",%d,%.2f,%.2f\n" str_X str_Y sup (conf * 100) lift
        end
    end
    println("\nSaved $(length(rules)) rules to: $out_csv")
end

main()