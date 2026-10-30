# Tiện ích I/O theo chuẩn SPMF và xử lý tham số dòng lệnh.

"""
    read_spmf(path) -> Vector{Vector{Int}}

Đọc CSDL giao dịch định dạng SPMF: mỗi dòng một giao dịch, các item là số nguyên
dương cách nhau bởi dấu cách. Bỏ qua dòng trống và dòng metadata bắt đầu bằng
`#`, `%`, `@`. Item trùng trong cùng một giao dịch chỉ được giữ một lần.
"""
function read_spmf(path::AbstractString)::Vector{Vector{Int}}
    db = Vector{Vector{Int}}()
    open(path, "r") do io
        for line in eachline(io)
            s = strip(line)
            (isempty(s) || first(s) in ('#', '%', '@')) && continue
            trans = parse.(Int, split(s))
            push!(db, unique!(trans))
        end
    end
    return db
end

"""
    minsup_to_count(minsup, n) -> Int

Đổi ngưỡng minsup sang số đếm tuyệt đối trên CSDL có `n` giao dịch.
- `0 < minsup <= 1`: minsup tương đối, trả về `ceil(minsup * n)` (giống SPMF).
- `minsup > 1`: coi là số đếm tuyệt đối.
"""
function minsup_to_count(minsup::Real, n::Integer)::Int
    minsup > 0 || throw(ArgumentError("minsup phải > 0, nhận được $minsup"))
    return minsup <= 1 ? ceil(Int, minsup * n) : ceil(Int, minsup)
end

"""
    write_spmf(path, itemsets)

Ghi các frequent itemset ra file theo định dạng SPMF, mỗi dòng một itemset:
`1 3 5 #SUP: 4`. `itemsets` là vector các cặp `(items, support)`. Item trong mỗi
itemset được sắp tăng dần để dễ so sánh với output của SPMF.
"""
function write_spmf(path::AbstractString, itemsets::AbstractVector{<:Tuple{AbstractVector{Int},Integer}})
    open(path, "w") do io
        for (items, sup) in itemsets
            join(io, sort(items), ' ')
            println(io, " #SUP: ", sup)
        end
    end
    return path
end

"""
    parse_cli(args = ARGS) -> Dict{String,Any}

Đọc tham số dòng lệnh. Ví dụ:
`julia --project=. demo.jl --minsup 0.01 data/benchmark.txt --output out.txt`
"""
function parse_cli(args::AbstractVector{<:AbstractString} = ARGS)
    s = ArgParseSettings(description = "FP-Growth: khai thác tập phổ biến từ file SPMF")
    @add_arg_table! s begin
        "input"
            help = "đường dẫn file CSDL đầu vào (định dạng SPMF .txt)"
            required = true
        "--minsup", "-s"
            help = "ngưỡng minsup: (0,1] là tương đối, > 1 là số đếm tuyệt đối"
            arg_type = Float64
            required = true
        "--output", "-o"
            help = "đường dẫn file kết quả"
            default = "output.txt"
    end
    return parse_args(args, s)
end

function filter_and_sort(Trans::AbstractVector{T}, FList::AbstractVector{T}) where T
    trans_items = Set(Trans)
    sorted_frequent_items = T[item for item in FList if item in trans_items]
    return sorted_frequent_items
end
