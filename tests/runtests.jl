using Test
include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))

@testset "FPGrowth" begin
    include("test_io.jl")
    include("test_fptree.jl")
end
