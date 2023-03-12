using CTFlows
using Test

 @testset verbose = true showtiming = true "CTFlows" begin
     for name in (
         "flow_function",
         "flow_hamiltonian", 
         "flow_vf_hamiltonian", 
         "flow_vf", 
         "concatenation"
         )
         @testset "$name" begin
             include("test_$name.jl")
         end
     end
 end