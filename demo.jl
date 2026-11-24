# Usage:
#   julia --project=. demo.jl data/toy/han2000.txt --minsup 0.6 --impl opt --output out.txt
#   julia --project=. demo.jl data/toy/han2000.txt --minsup 0.6 --impl basic --output out.txt
#   julia --project=. demo.jl data/toy/han2000.txt --minsup 0.6 --impl both --output out.txt

using Printf

include(joinpath(@__DIR__, "src", "FPGrowth.jl"))
using .FPGrowth

function run_impl(::Type{T}, label::String, db, minsup_count::Int, show_tree::Bool) where {T}
    t_build = @elapsed tree = fptree_construction(T, db, minsup_count)
    t_mine  = @elapsed itemsets = fpgrowth(tree, minsup_count)

    println("\n=== $label ($T) ===")
    println("FP-tree node count: ", count_nodes(tree))
    @printf("Time: build = %.4fs | mining = %.4fs | total = %.4fs\n",
            t_build, t_mine, t_build + t_mine)
    println("Frequent itemsets: ", length(itemsets))
    show_tree && print_tree(tree)

    return itemsets
end

function main(args)
    opts = parse_cli(args)
    impl = lowercase(opts["impl"])
    impl in ("basic", "opt", "both") || error("Invalid --impl '$impl'. Choose: basic, opt, or both.")

    db = read_spmf(opts["input"])
    minsup_count = minsup_to_count(opts["minsup"], length(db))
    println("Transactions: ", length(db), ", minsup_count = ", minsup_count)

    support = count_supports(db)
    FList = build_flist(support, minsup_count)
    println("F-list: ", join(("$i:$(support[i])" for i in FList), " "))
    show_tree = length(FList) <= 30

    if impl == "basic"
        itemsets = run_impl(FPTree, "Basic", db, minsup_count, show_tree)
    elseif impl == "opt"
        itemsets = run_impl(OptFPTree, "Optimized", db, minsup_count, show_tree)
    else
        base_sets = run_impl(FPTree, "Basic", db, minsup_count, show_tree)
        opt_sets  = run_impl(OptFPTree, "Optimized", db, minsup_count, false)
        matched   = Set((sort(x), c) for (x, c) in base_sets) == Set((sort(x), c) for (x, c) in opt_sets)
        println("\nBasic vs. Optimized verification: ", matched ? "100% MATCH" : "MISMATCH!")
        itemsets = opt_sets
    end

    write_spmf(opts["output"], itemsets)
    println("Wrote ", length(itemsets), " itemsets to ", opts["output"])
end

main(ARGS)