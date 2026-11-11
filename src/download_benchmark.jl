using Downloads

const SPMF_BASE = "https://www.philippe-fournier-viger.com/spmf/publicdatasets"

const DATASETS = Dict(
    "chess.txt"      => "$SPMF_BASE/chess.txt",
    "mushroom.txt"   => "$SPMF_BASE/mushroom.txt",
    "retail.txt"     => "$SPMF_BASE/retail.txt",
    "accidents.txt"  => "$SPMF_BASE/accidents.txt"
)

# Navigate from scripts/ up to the root, then into data/benchmark/
out_dir = joinpath(@__DIR__, "..", "data", "benchmark")
mkpath(out_dir)

for (filename, url) in DATASETS
    filepath = joinpath(out_dir, filename)
    if !isfile(filepath)
        println("Downloading $filename from SPMF...")
        try
            Downloads.download(url, filepath)
            println("Successfully saved to $filepath")
        catch e
            println("Error downloading $filename: $e")
        end
    else
        println("$filename already exists, skipping.")
    end
end