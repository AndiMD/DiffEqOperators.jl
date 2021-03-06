include("src/DiffEqOperators.jl")
using .DiffEqOperators
using LinearAlgebra, Random, Test

# Generate random parameters
al = rand(ComplexF64,5)
bl = rand(ComplexF64,5)
cl = rand(ComplexF64,5)
dx = rand(Float64,5)
ar = rand(ComplexF64,5)
br = rand(ComplexF64,5)
cr = rand(ComplexF64,5)

# Construct 5 arbitrary RobinBC operators for each parameter set
for i in 1:5
	
	Q = RobinBC((al[i], bl[i], cl[i]), (ar[i], br[i], cr[i]), dx[i])

	Q_L, Q_b = Array(Q,5i)

	#Check that Q_L is is correctly computed
	@test Q_L[2:5i+1,1:5i] ≈ Array(I, 5i, 5i)
	@test Q_L[1,:] ≈ [1 / (1-al[i]*dx[i]/bl[i]); zeros(5i-1)]
	@test Q_L[5i+2,:] ≈ [zeros(5i-1); 1 / (1+ar[i]*dx[i]/br[i])]

	#Check that Q_b is computed correctly
	@test Q_b ≈ [cl[i]/(al[i]-bl[i]/dx[i]); zeros(5i); cr[i]/(ar[i]+br[i]/dx[i])]

	# Construct the extended operator and check that it correctly extends u to a (5i+2)
	# vector, along with encoding boundary condition information.
	u = rand(ComplexF64,5i)

	Qextended = Q*u
	CorrectQextended = [(cl[i]-(bl[i]/dx[i])*u[1])/(al[i]-bl[i]/dx[i]); u; (cr[i]+ (br[i]/dx[i])*u[5i])/(ar[i]+br[i]/dx[i])]
	@test length(Qextended) ≈ 5i+2

	# Check concretization
	@test Array(Qextended) ≈ CorrectQextended # 	Q.a_l ⋅ u[1:length(Q.a_l)] + Q.b_l, 		Q.a_r ⋅ u[(end-length(Q.a_r)+1):end] + Q.b_r

	# Check that Q_L and Q_b correctly compute BoundaryPaddedVector
	@test Q_L*u + Q_b ≈ CorrectQextended

	@test [Qextended[1]; Qextended.u; Qextended[5i+2]] ≈ CorrectQextended
	
end
