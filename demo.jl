# Cách chạy: julia --project=. demo.jl --minsup 0.6 data/toy/han2000.txt --output out.txt

include(joinpath(@__DIR__, "src", "FPGrowth.jl"))
using .FPGrowth

function main(args)
    opts = parse_cli(args)
    db = read_spmf(opts["input"])
    minsup_count = minsup_to_count(opts["minsup"], length(db))
    println("Số giao dịch: ", length(db), ", minsup_count = ", minsup_count)

    tree = build_fptree(db, minsup_count)
    println("F-list: ", join(("$i:$(tree.support[i])" for i in tree.flist), " "))
    println("Số node của FP-tree: ", count_nodes(tree))
    length(tree.flist) <= 30 && print_tree(tree)

    # TODO: thay bằng kết quả fp_growth(tree, minsup_count) khi cài xong FP-Growth.
    itemsets = [([i], tree.support[i]) for i in tree.flist]
    write_spmf(opts["output"], itemsets)
    println("Đã ghi ", length(itemsets), " itemset vào ", opts["output"])
end

main(ARGS)
