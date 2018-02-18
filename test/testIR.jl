using DiffEqOperators #, Plots, SpecialFunctions
n = 100
# dx = rand(n)/100;
# x = erf.(linspace(-2,2,n))*2π;
# x +=abs(x[1]);
# dx = diff(x)
# # dx = ones(n)*0.04;
# x = [0.0;cumsum(dx)]
x=0.0:0.01:2π
dx=diff(x)






D1 = DerivativeOperator{Float64}(1,2,dx[1],length(x),:None,:None)
C1 = full(D1)
D2 = DiffEqOperators.FiniteDifference{Float64}(1,2,dx,length(x),:None,:None)


C2 = full(D2)

# spy(C2)
y = sin.(x);
y[10:end-9] ≈ (C2*y)[10:end-9]

plot(x,y)
plot!(x,C2*y)
plot(x[end-10:end],(y - C2*y)[end-10:end])
# C*y
plot(x,y,label="y")
plot!(x,C1*y,label="dy/dx do")
plot!(x,C2*y,label="dy/dx fd",legend=:top)
# plot!(x[2:end-2],C2[1:end-3,1:end-3]*y[2:end-2],m=2,ylim=(-1,1))

D2
# x = [  1.00000000e-02,   3.59337133e-02,   6.39227225e-02,
#          9.41387744e-02,   1.26759071e-01,   1.61974916e-01,
#          1.99992831e-01,   2.41035773e-01,   2.85344440e-01,
#          3.33178680e-01,   3.84819017e-01,   4.40568297e-01,
#          5.00753463e-01,   5.65727469e-01,   6.35871359e-01,
#          7.11596490e-01,   7.93346955e-01,   8.81602179e-01,
#          9.76879737e-01,   1.07973838e+00,   1.19078134e+00,
#          1.31065981e+00,   1.44007683e+00,   1.57979136e+00,
#          1.73062276e+00,   1.89345559e+00,   2.06924478e+00,
#          2.24503397e+00,   2.42082316e+00,   2.59661235e+00,
#          2.77240154e+00,   2.94819072e+00,   3.12397991e+00,
#          3.29976910e+00,   3.47555829e+00,   3.65134748e+00,
#          3.82713667e+00,   4.00292586e+00,   4.17871504e+00,
#          4.35450423e+00,   4.53029342e+00,   4.70608261e+00,
#          4.88187180e+00,   5.05766099e+00,   5.23345018e+00,
#          5.40923936e+00,   5.58502855e+00,   5.76081774e+00,
#          5.93660693e+00,   6.11239612e+00,   6.28818531e+00,
#          6.46397450e+00,   6.63976368e+00,   6.81555287e+00,
#          6.99134206e+00,   7.16713125e+00,   7.34292044e+00,
#          7.51870963e+00,   7.69449882e+00,   7.87028800e+00,
#          8.04607719e+00,   8.22186638e+00,   8.39765557e+00,
#          8.57344476e+00,   8.74923395e+00,   8.92502314e+00,
#          9.10081232e+00,   9.27660151e+00,   9.45239070e+00,
#          9.62817989e+00,   9.80396908e+00,   9.97975827e+00,
#          1.01555475e+01,   1.03313366e+01,   1.05071258e+01,
#          1.06829150e+01,   1.08457479e+01,   1.09965793e+01,
#          1.11362938e+01,   1.12657108e+01,   1.13855893e+01,
#          1.14966322e+01,   1.15994909e+01,   1.16947684e+01,
#          1.17830237e+01,   1.18647741e+01,   1.19404993e+01,
#          1.20106431e+01,   1.20756172e+01,   1.21358023e+01,
#          1.21915516e+01,   1.22431919e+01,   1.22910262e+01,
#          1.23353348e+01,   1.23763778e+01,   1.24143957e+01,
#          1.24496115e+01,   1.24822318e+01,   1.25124479e+01,
#          1.25404369e+01,   1.25663706e+01];
#
# dx = diff(x)
# D = DiffEqOperators.FiniteDifference{Float64}(1,2,dx,length(x),:Dirichlet0,:None)
#
# C = sparse(D)
# spy(C)
# y=sin.(x)
# C*y
# plot(x,y)
# # plot!(x[2:end-1],C[1:end-2,1:end-2]*y[2:end-1],m=2)
# plot!(x[2:end-2],(C[1:end-2,1:end-2]*y[2:end-1])[1:end-1],m=2)
#
# x = collect(0 : 1/99 : 1);
#
# u0 = x.^2 -x;
#
# A = DerivativeOperator{Float64}(2,2,1/99,10,:Dirichlet,:Dirichlet; bndry_fn=(t->(u[1]*cos(t)),u0[end]))
# A2 = FiniteDifference{Float64}(2,2,ones(9)*1/99,10,:Dirichlet,:Dirichlet; bndry_fn=(t->(u[1]*cos(t)),u0[end]))
#
#
#
# res = A*u0
