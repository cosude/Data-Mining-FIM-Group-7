# Ứng dụng 2: khai thác mẫu trên chuỗi DNA quanh điểm nối exon/intron (UCI Splice-junction).
# Đầu vào trong data/splice/ (tạo bởi ô chuẩn bị dữ liệu trong demo notebook):
#   splice_EI.txt, splice_IE.txt, splice_N.txt  - mỗi dòng một đoạn DNA, item = (vị trí, nucleotide)
#   splice_mapping.csv                           - id -> tên item, vd 123 -> p31=G
# Đầu ra: in bảng top mẫu cho EI và IE, ghi CSV vào data/results/app2_splice/.
using Printf
using ArgParse

include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

const DATA_DIR = normpath(joinpath(@__DIR__, "..", "data", "splice"))
const CLASSES = ("EI", "IE", "N")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--minsup", "-s"
            help = "Minimum support (relative in (0, 1] or absolute integer count > 1)"
            arg_type = Float64
            default = 0.4
        "--top", "-k"
            help = "Number of top patterns to display"
            arg_type = Int
            default = 10
    end
    return parse_args(s)
end

function load_mapping(filepath::String)
    mapping = Dict{Int, String}()
    for line in readlines(filepath)[2:end]
        id, name = split(strip(line), ",")
        mapping[parse(Int, id)] = String(name)
    end
    return mapping
end

# Support tương đối của `itemset` trong `db` (mỗi giao dịch đã đổi sang BitSet để tra nhanh)
rel_support(itemset, db_sets) = count(t -> all(in(t), itemset), db_sets) / length(db_sets)

itemset_name(itemset, mapping) = join((mapping[i] for i in sort(itemset)), ", ")

function main()
    args = parse_commandline()
    minsup_arg = args["minsup"]
    top_k      = args["top"]

    mapping = load_mapping(joinpath(DATA_DIR, "splice_mapping.csv"))
    dbs = Dict(c => read_spmf(joinpath(DATA_DIR, "splice_$(c).txt")) for c in CLASSES)
    n_sets = [BitSet(t) for t in dbs["N"]]
    floor_N = 1 / length(n_sets)   # tránh chia cho 0 khi mẫu không xuất hiện trong N

    out_dir = mkpath(normpath(joinpath(@__DIR__, "..", "data", "results", "app2_splice")))

    # Tần suất từng nucleotide ở từng vị trí (support của các 1-itemset), dùng để vẽ hình
    open(joinpath(out_dir, "position_freq.csv"), "w") do io
        println(io, "Class,Position,Base,Freq")
        for c in CLASSES
            sup = count_supports(dbs[c])
            for (id, cnt) in sup
                pos, base = split(mapping[id][2:end], "=")
                println(io, "$c,$pos,$base,$(cnt / length(dbs[c]))")
            end
        end
    end

    open(joinpath(out_dir, "patterns.csv"), "w") do io
        println(io, "Class,Itemset,Length,Support_Count,Support,Support_N,Growth_Rate")
        for c in ("EI", "IE")
            db = dbs[c]
            n = length(db)
            itemsets = fpgrowth(OptFPTree, db, minsup_to_count(minsup_arg, n))

            # So với lớp N: growth rate = support trong lớp c / support trong N
            rows = map(itemsets) do (items, cnt)
                sup_N = rel_support(items, n_sets)
                (items = items, cnt = cnt, sup = cnt / n, sup_N = sup_N, growth = (cnt / n) / max(sup_N, floor_N))
            end
            for r in rows
                println(io, join((c, "\"" * itemset_name(r.items, mapping) * "\"", length(r.items), r.cnt, r.sup, r.sup_N, r.growth), ','))
            end

            println("\n=== Lớp $c: $n đoạn DNA, minsup = $minsup_arg -> $(length(itemsets)) tập phổ biến ===")
            for (title, key) in (("Top $top_k theo support", r -> -r.sup), ("Top $top_k theo growth rate so với N", r -> -r.growth))
                println("\n--- $title (độ dài >= 2) ---")
                @printf "%-45s | %9s | %9s | %8s\n" "Itemset" "Sup($c)" "Sup(N)" "Growth"
                println("-"^80)
                for r in first(sort(filter(r -> length(r.items) >= 2, rows); by = key), top_k)
                    @printf "%-45s | %8.1f%% | %8.1f%% | %8.1f\n" itemset_name(r.items, mapping) 100r.sup 100r.sup_N r.growth
                end
            end
        end
    end

    # Đối chứng: lớp N (không có điểm nối) khai thác cùng ngưỡng
    n_itemsets = fpgrowth(OptFPTree, dbs["N"], minsup_to_count(minsup_arg, length(dbs["N"])))
    println("\n=== Lớp N: $(length(dbs["N"])) đoạn DNA, minsup = $minsup_arg -> $(length(n_itemsets)) tập phổ biến ===")
    println("\nKết quả đã ghi vào: $out_dir")
end

main()