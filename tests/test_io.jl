using Test
isdefined(Main, :FPGrowth) || include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

@testset "SPMF I/O" begin
    @testset "read_spmf bỏ dòng trống, metadata, item trùng" begin
        path = tempname()
        write(path, "@CONVERTED_FROM_TEXT\n# comment\n1 2 3\n\n  4 5  \n% meta\n2 2 7\n")
        @test read_spmf(path) == [[1, 2, 3], [4, 5], [2, 7]]
    end

    @testset "minsup_to_count" begin
        @test minsup_to_count(0.6, 5) == 3
        @test minsup_to_count(0.5, 5) == 3       # làm tròn lên: 2.5 -> 3
        @test minsup_to_count(1.0, 5) == 5
        @test minsup_to_count(3, 5) == 3          # > 1 là số tuyệt đối
        @test_throws ArgumentError minsup_to_count(0, 5)
        @test_throws ArgumentError minsup_to_count(-0.1, 5)
    end

    @testset "write_spmf đúng định dạng" begin
        path = tempname()
        write_spmf(path, [([3, 1], 4), ([5], 2)])
        @test readlines(path) == ["1 3 #SUP: 4", "5 #SUP: 2"]
    end

    @testset "parse_cli" begin
        opts = parse_cli(["--minsup", "0.01", "data/x.txt", "-o", "out.txt"])
        @test opts["minsup"] == 0.01
        @test opts["input"] == "data/x.txt"
        @test opts["output"] == "out.txt"
        defaults = parse_cli(["data/x.txt"])
        @test defaults["minsup"] == 0.6
        @test defaults["impl"] == "opt"
        @test defaults["output"] == "out.txt"
        @test parse_cli(["data/x.txt", "-m", "both"])["impl"] == "both"
    end
end
