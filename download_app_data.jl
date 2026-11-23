using Downloads

const ROOT = @__DIR__

function prepare_market_basket()
    url = "https://raw.githubusercontent.com/stedy/Machine-Learning-with-R-datasets/master/groceries.csv"
    data_dir = mkpath(joinpath(ROOT, "data", "market_basket"))

    raw_path     = joinpath(data_dir, "groceries.csv")
    encoded_path = joinpath(data_dir, "encoded_groceries.txt")
    mapping_path = joinpath(data_dir, "mapping.csv")

    if !isfile(raw_path)
        println("Downloading Market Basket dataset...")
        Downloads.download(url, raw_path)
    end

    item_to_id = Dict{String, Int}()
    current_id = 1

    open(encoded_path, "w") do data_out
        open(mapping_path, "w") do map_out
            println(map_out, "ID,Item")
            for line in eachline(raw_path)
                items = [strip(i) for i in split(strip(line), ",") if !isempty(strip(i))]
                isempty(items) && continue

                encoded_tx = Int[]
                for item in items
                    item_str = String(item)
                    id = get!(item_to_id, item_str) do
                        val = current_id
                        println(map_out, "$val,$item_str")
                        current_id += 1
                        return val
                    end
                    push!(encoded_tx, id)
                end
                println(data_out, join(encoded_tx, " "))
            end
        end
    end

    println("Market Basket: encoded $(length(item_to_id)) items into '$data_dir'.")
end

function prepare_splice()
    url = "https://archive.ics.uci.edu/ml/machine-learning-databases/molecular-biology/splice-junction-gene-sequences/splice.data"
    data_dir = mkpath(joinpath(ROOT, "data", "splice"))
    raw_path = joinpath(data_dir, "splice.data")

    if !isfile(raw_path)
        println("Downloading UCI Splice-junction dataset...")
        Downloads.download(url, raw_path)
    end

    bases = ('A', 'C', 'G', 'T')
    base_idx = Dict('A' => 1, 'C' => 2, 'G' => 3, 'T' => 4)
    item_id(pos::Int, base::Char) = (pos - 1) * 4 + base_idx[base]

    classes = ("EI", "IE", "N")
    outs = Dict(c => open(joinpath(data_dir, "splice_$(c).txt"), "w") for c in classes)
    counts = Dict(c => 0 for c in classes)

    try
        for line in eachline(raw_path)
            s = strip(line)
            isempty(s) && continue
            parts = strip.(split(s, ","))
            label = uppercase(String(parts[1]))
            seq   = uppercase(String(parts[3]))

            items = [item_id(i, b) for (i, b) in enumerate(seq) if haskey(base_idx, b)]
            println(outs[label], join(items, " "))
            counts[label] += 1
        end
    finally
        for io in values(outs)
            close(io)
        end
    end

    open(joinpath(data_dir, "splice_mapping.csv"), "w") do map_out
        println(map_out, "ID,Item")
        for pos in 1:60
            for b in bases
                println(map_out, "$(item_id(pos, b)),p$(pos)=$(b)")
            end
        end
    end

    println("Splice-junction: encoded $counts into '$data_dir'.")
end

function main()
    prepare_market_basket()
    prepare_splice()
end

main()