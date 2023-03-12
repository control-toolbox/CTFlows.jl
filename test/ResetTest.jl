module ResetTest

# to use it
# include("test/ResetTest.jl"); using .ResetTest

#
import Pkg: Operations.testdir, Operations.testfile, Pkg.Operations, Pkg

Operations.testdir(source_path::String) = joinpath(source_path, "test")
Operations.testfile(source_path::String) = joinpath(testdir(source_path), "runtests.jl")

end