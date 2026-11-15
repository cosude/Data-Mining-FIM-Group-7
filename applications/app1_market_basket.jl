using Printf
using Combinatorics

include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

function load_mapping(filepath::String)
    mapping = Dict{Int, String}()
    lines = readlines(filepath)[2:end]
    for line in lines
        parts = split(line, ",")
        if length(parts) == 2
            mapping[parse(Int, parts[1])] = parts[2]
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
    println("Mining frequent itemsets...")
    db = read_spmf("encoded_groceries.txt")
    mapping = load_mapping("mapping.csv")
    total_trans = length(db)
    
    minsup_count = minsup_to_count(0.01, total_trans)
    
    itemsets = fpgrowth(OptFPTree, db, minsup_count)
    
    rules = generate_association_rules(itemsets, total_trans, 0.2)
    
    println("\n--- TOP 10 ASSOCIATION RULES (Based on Lift) ---")
    @printf "%-50s | %-8s | %-8s | %-6s\n" "Rule (X -> Y)" "Support" "Conf(%)" "Lift"
    println("-"^80)
    
    for i in 1:min(10, length(rules))
        X, Y, sup, conf, lift = rules[i]
        
        str_X = join([mapping[item] for item in X], ", ")
        str_Y = join([mapping[item] for item in Y], ", ")
        rule_str = "{$str_X} => {$str_Y}"
        
        @printf "%-50s | %-8d | %-8.2f | %-6.2f\n" rule_str sup (conf * 100) lift
    end
end

main()