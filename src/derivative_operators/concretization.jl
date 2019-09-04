#
# Casting to normal matrix types.
#
# This implements the casts described in README.md, and the cast from
# BoundaryPaddedArray to Array.
#

function Base.copyto!(L::AbstractMatrix{T}, A::DerivativeOperator{T}, N::Int) where T
    bl = A.boundary_point_count
    stencil_length = A.stencil_length
    stencil_pivot = use_winding(A) ? (1 + stencil_length%2) : div(stencil_length,2)
    bstl = A.boundary_stencil_length

    coeff   = A.coefficients
    get_coeff = if coeff isa AbstractVector
        i -> coeff[i]
    elseif coeff isa Number
        i -> coeff
    else
        i -> true
    end

    for i in 1:bl
        cur_coeff   = get_coeff(i)
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(A.low_boundary_coefs[i]) : A.low_boundary_coefs[i]
        L[i,1:bstl] = cur_coeff * cur_stencil
    end

    for i in bl+1:N-bl
        cur_coeff   = get_coeff(i)
        stencil     = eltype(A.stencil_coefs) <: AbstractVector ? A.stencil_coefs[i-bl] : A.stencil_coefs
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(stencil) : stencil
        L[i,i+1-stencil_pivot:i-stencil_pivot+stencil_length] = cur_coeff * cur_stencil
    end

    for i in N-bl+1:N
        cur_coeff   = get_coeff(i)
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(A.high_boundary_coefs[i-N+bl]) : A.high_boundary_coefs[i-N+bl]
        L[i,N-bstl+3:N+2] = cur_coeff * cur_stencil
    end

    L
end

LinearAlgebra.Array(A::DerivativeOperator{T}, N::Int=A.len) where T =
    copyto!(zeros(T, N, N+2), A, N)

SparseArrays.SparseMatrixCSC(A::DerivativeOperator{T}, N::Int=A.len) where T =
    copyto!(spzeros(T, N, N+2), A, N)

SparseArrays.sparse(A::DerivativeOperator{T}, N::Int=A.len) where T = SparseMatrixCSC(A,N)

function BandedMatrices.BandedMatrix(A::DerivativeOperator{T}, N::Int=A.len) where T
    stencil_length = A.stencil_length
    bstl = A.boundary_stencil_length
    L = BandedMatrix{T}(Zeros(N, N+2), (max(stencil_length-3,0,bstl),max(stencil_length-1,0,bstl)))
    copyto!(L, A, N)
end

Base.convert(::Type{Mat}, A::DerivativeOperator) where {Mat<:Union{Array,SparseMatrixCSC,BandedMatrix}} =
    Mat(A)

Base.convert(::Type{AbstractMatrix},A::DerivativeOperator) =
    BandedMatrix(A)

################################################################################
# Boundary Padded Array concretizations
################################################################################

function LinearAlgebra.Array(Q::BoundaryPaddedArray{T,D,N,M,V,B}) where {T,D,N,M,V,B}
    S = size(Q)
    out = zeros(T, S...)
    dim = D
    ulowview = selectdim(out, dim, 1)
    uhighview = selectdim(out, dim, S[dim])
    uview = selectdim(out, dim, 2:(S[dim]-1))
    ulowview .= Q.lower
    uhighview .= Q.upper
    uview .= Q.u
    return out
end

function LinearAlgebra.Array(Q::ComposedBoundaryPaddedArray{T,N,M,V,B}) where {T,N,M,V,B}
    S = size(Q)
    out = zeros(T, S...)
    dimset = 1:N
    uview = out
    for dim in dimset
        ulowview = selectdim(out, dim, 1)
        uhighview = selectdim(out, dim, S[dim])
        uview = selectdim(uview, dim, 2:(S[dim]-1))
        for (index, otherdim) in enumerate(setdiff(dimset, dim))
            ulowview = selectdim(ulowview, index, 2:(S[otherdim]-1))
            uhighview = selectdim(uhighview, index, 2:(S[otherdim]-1))
        end
        ulowview .= Q.lower[dim]
        uhighview .= Q.upper[dim]
    end
    uview .= Q.u
    return out
end

function Base.convert(::Type{AbstractArray}, A::AbstractBoundaryPaddedArray)
    Array(A)
end

################################################################################
# Boundary Condition Operator concretizations
################################################################################

#Atomic BCs
function LinearAlgebra.Array(Q::AffineBC{T}, N::Int) where {T}
    Q_L = [transpose(Q.a_l) transpose(zeros(T, N-length(Q.a_l))); Diagonal(ones(T,N)); transpose(zeros(T, N-length(Q.a_r))) transpose(Q.a_r)]
    Q_b = [Q.b_l; zeros(T,N); Q.b_r]
    return (Array(Q_L), Q_b)
end

function SparseArrays.SparseMatrixCSC(Q::AffineBC{T}, N::Int) where {T}
    Q_L = [transpose(Q.a_l) transpose(zeros(T, N-length(Q.a_l))); Diagonal(ones(T,N)); transpose(zeros(T, N-length(Q.a_r))) transpose(Q.a_r)]
    Q_b = [Q.b_l; zeros(T,N); Q.b_r]
    return (Q_L, Q_b)
end

function BandedMatrices.BandedMatrix(Q::AffineBC{T}, N::Int) where {T}
    Q_l = BandedMatrix{T}(Eye(N), (length(Q.a_r)-1, length(Q.a_l)-1))
    BandedMatrices.inbands_setindex!(Q_l, Q.a_l, 1, 1:length(Q.a_l))
    BandedMatrices.inbands_setindex!(Q_l, Q.a_r, N, (N-length(Q.a_r)+1):N)
    Q_b = [Q.b_l; zeros(T,N); Q.b_r]
    return (Q_l, Q_b)
end

function SparseArrays.sparse(Q::AffineBC{T}, N::Int) where {T}
    SparseMatrixCSC(Q,N)
end

LinearAlgebra.Array(Q::PeriodicBC{T}, N::Int) where T = (Array([transpose(zeros(T, N-1)) one(T); Diagonal(ones(T,N)); one(T) transpose(zeros(T, N-1))]), zeros(T, N))
SparseArrays.SparseMatrixCSC(Q::PeriodicBC{T}, N::Int) where T = ([transpose(zeros(T, N-1)) one(T); Diagonal(ones(T,N)); one(T) transpose(zeros(T, N-1))], zeros(T, N))
SparseArrays.sparse(Q::PeriodicBC{T}, N::Int) where T = SparseMatrixCSC(Q,N)
function BandedMatrices.BandedMatrix(Q::PeriodicBC{T}, N::Int) where T #Not reccomended!
    Q_array = BandedMatrix{T}(Eye(N), (N-1, N-1))
    Q_array[1, end] = one(T)
    Q_array[1, 1] = zero(T)
    Q_array[end, 1] = one(T)
    Q_array[end, end] = zero(T)

    return (Q_array, zeros(T, N))
end

function LinearAlgebra.Array(Q::BoundaryPaddedVector)
    return [Q.l; Q.u; Q.r]
end

function Base.convert(::Type{Array},A::AbstractBC{T}) where T
    Array(A)
end

function Base.convert(::Type{SparseMatrixCSC},A::AbstractBC{T}) where T
    SparseMatrixCSC(A)
end

function Base.convert(::Type{AbstractMatrix},A::AbstractBC{T}) where T
    SparseMatrixCSC(A)
end

# Multi dimensional BC operators
_concretize(Q::MultiDimDirectionalBC, M) = _concretize(Q.BCs, M)

function _concretize(Q::AbstractArray{T,N}, M) where {T,N}
    return (stencil.(Q, fill(M,size(Q))), affine.(Q))
end

function c2l(I::CartesianIndex, s) #Not sure if there is a builtin that does this
    out = I[1]
    for i in 1:length(s)-1
        out += (I[i+1]-1)*prod(s[1:i])
    end
    return out
end

function LinearAlgebra.Array(Q::MultiDimDirectionalBC{T, B, D, N, K}, M) where {T, B, D,N,K}
    blip = zeros(Int64, N)
    blip[D] = 2
    s_pad = s.+ blip # extend s in the right direction
    Q = _concretize.(Q.BCs, s)
    ē = unit_indices(N)
    QL = zeros(T, prod(s_pad), prod(s))
    Qb = zeros(T, prod(s_pad))
    ranges = Union{typeof(1:10), Int64}[1:s[i] for i in 1:N]
    ranges[D] = ranges[D] .+ 1

    interior = CartesianIndices(Tuple(ranges))
    I1 = CartesianIndex(Tuple(ones(Int64, N)))
    for I in interior
        i = c2l(I, s_pad)
        j = c2l(I-I1, s)
        QL[i,j] = one(T)
    end
    ranges[D] = 1
    lower = CartesianIndices((Tuple(ranges)))
    ranges[D] = s_pad[D]
    upper = CartesianIndices((Tuple(ranges)))
    for K in CartesianIndices(upper)
        I = CartesianIndex(Tuple(K)[setdiff(1:N, D)])
        il = c2l(lower[K], s_pad)
        iu = c2l(upper[K], s_pad)
        Qb[il] = Q[2][I][1]
        Qb[iu] = Q[2][I][2]
        for k in 1:s[D]
            j = c2l(lower[K] + k*ē[D]- I1, s)
            QL[il, j] = Q[1][I][1][k]
            QL[iu, j] = Q[1][I][2][k]
        end
    end

    return (QL, Qb)
end

"""
This is confusing, but it does work
"""
function LinearAlgebra.Array(Q::ComposedMultiDimBC{T, B, N,M} , s) where {T, B, N, M}
    s_pad = s.+2
    Q = Tuple(_concretize.(Q.BCs, s)) #essentially finding the first and last rows of the matrix part and affine part for every atomic BC

    QL = zeros(T, prod(s_pad), prod(s))
    Qb = zeros(T, prod(s_pad))

    ranges = Union{typeof(1:10), Int64}[2:s_pad[i]-1 for i in 1:N] #Set up indices corresponding to the interior
    interior = CartesianIndices(Tuple(ranges))

    ē = unit_indices(N) #setup unit indices in each direction
    I1 = CartesianIndex(Tuple(ones(Int64, N))) #setup the ones index
    for I in interior #loop over interior
        i = c2l(I, s_pad) #find the index on the padded side
        j = c2l(I-I1, s)  #find the index on the unpadded side
        QL[i,j] = one(T)  #create a padded identity matrix
    end
    for dim in 1:N #Loop over boundaries
        r_ = deepcopy(ranges)
        r_[dim] = 1
        lower = CartesianIndices((Tuple(r_))) #set up upper anmd lower indices
        r_[dim] = s_pad[dim]
        upper = CartesianIndices((Tuple(r_)))
        for K in CartesianIndices(upper) #for every element of the boundaries
            I = CartesianIndex(Tuple(K)[setdiff(1:N, dim)]) #convert K to 2D index for indexing the BC arrays
            il = c2l(lower[K], s_pad) #Translate to linear indices
            iu = c2l(upper[K], s_pad) # ditto
            Qb[il] = Q[dim][2][I][1] #store the affine parts in indices corresponding with the lower index boundary
            Qb[iu] = Q[dim][2][I][2] #ditto with upper index
            for k in 1:s[dim] #loop over the direction orthogonal to the boundary
                j = c2l(lower[K] + k*ē[dim]-I1, s) #Find the linear index this element of the boundary stencil should be at on the unpadded side
                QL[il, j] = Q[dim][1][I][1][k]
                QL[iu, j] = Q[dim][1][I][2][k]
            end
        end
    end

    return (QL, Qb)
end

"""
See comments on the `Array` method for this type for an idea of what is going on
"""
function SparseArrays.SparseMatrixCSC(Q::MultiDimDirectionalBC{T, B, D, N, K}, M) where {T, B, D,N,K}
    blip = zeros(Int64, N)
    blip[D] = 2
    s_pad = s.+ blip
    Q = _concretize.(Q.BCs, s)
    ē = unit_indices(N)
    QL = spzeros(T, prod(s_pad), prod(s))
    Qb = spzeros(T, prod(s_pad))
    ranges = Union{typeof(1:10), Int64}[1:s[i] for i in 1:N]
    ranges[D] = ranges[D] .+ 1

    interior = CartesianIndices(Tuple(ranges))
    I1 = CartesianIndex(Tuple(ones(Int64, N)))
    for I in interior
        i = c2l(I, s_pad)
        j = c2l(I-I1, s)
        QL[i,j] = one(T)
    end
    ranges[D] = 1
    lower = CartesianIndices((Tuple(ranges)))
    ranges[D] = s_pad[D]
    upper = CartesianIndices((Tuple(ranges)))
    for K in CartesianIndices(upper)
        I = CartesianIndex(Tuple(K)[setdiff(1:N, D)])
        il = c2l(lower[K], s_pad)
        iu = c2l(upper[K], s_pad)
        Qb[il] = Q[2][I][1]
        Qb[iu] = Q[2][I][2]
        for k in 1:s[D]
            j = c2l(lower[K] + k*ē[D]- I1, s)
            QL[il, j] = Q[1][I][1][k]
            QL[iu, j] = Q[1][I][2][k]
        end
    end

    return (QL, Qb)
end


function SparseArrays.SparseMatrixCSC(Q::ComposedMultiDimBC{T, B, N,M} , s) where {T, B, N, M}
    s_pad = s.+2
    Q = Tuple(_concretize.(Q.BCs, s))
    ē = unit_indices(N)
    QL = spzeros(T, prod(s_pad), prod(s))
    Qb = spzeros(T, prod(s_pad))
    ranges = Union{typeof(1:10), Int64}[2:s_pad[i]-1 for i in 1:N]

    interior = CartesianIndices(Tuple(ranges))
    I1 = CartesianIndex(Tuple(ones(Int64, N)))
    for I in interior
        i = c2l(I, s_pad)
        j = c2l(I-I1, s)
        QL[i,j] = one(T)
    end
    for dim in 1:N
        r_ = deepcopy(ranges)
        r_[dim] = 1
        lower = CartesianIndices((Tuple(r_)))
        r_[dim] = s_pad[dim]
        upper = CartesianIndices((Tuple(r_)))
        for K in CartesianIndices(upper)
            I = CartesianIndex(Tuple(K)[setdiff(1:N, dim)])
            il = c2l(lower[K], s_pad)
            iu = c2l(upper[K], s_pad)
            Qb[il] = Q[dim][2][I][1]
            Qb[iu] = Q[dim][2][I][2]
            for k in 1:s[dim]
                j = c2l(lower[K] + k*ē[dim]-I1, s)
                QL[il, j] = Q[dim][1][I][1][k]
                QL[iu, j] = Q[dim][1][I][2][k]
            end
        end
    end

    return (QL, Qb)
end

SparseArrays.sparse(Q::MultiDimDirectionalBC, N) = SparseMatrixCSC(Q, N)
SparseArrays.sparse(Q::ComposedMultiDimBC, N) = SparseMatrixCSC(Q, N)


function BandedMatrices.BandedMatrix(Q::MultiDimDirectionalBC{T, B, D, N, K}, M) where {T, B, D,N,K}
    bc_tuples = BandedMatrix.(Q.BCs, fill(M, size(Q.BCs)))
    Q_L = [bc_tuple[1] for bc_tuple in bc_tuples]
    inds = Array(1:N)
    inds[1], inds[D] = inds[D], inds[1]
    Q_b = [permutedims(add_dims(bc_tuple[2], N-1),inds) for bc_tuple in bc_tuples]

    return (Q_L, Q_b)
end

"""
Returns a Tuple of MultiDimDirectionalBC Array concretizations, one for each dimension
"""
SparseArrays.sparse(Q::ComposedMultiDimBC, Ns) = SparseMatrixCSC(Q, Ns)

# HIgher Dimensional Concretizations. The following concretizations return two dimensional arrays
# which operate on flattened vectors. Mshape is the size of the unflattened array on which A is operating on.

function LinearAlgebra.Array(A::DerivativeOperator{T,N}, Mshape) where {T,N}
    # Case where A is not differentiating along the first dimension
    if N != 1
        n = prod(Mshape[1:N-1])
        B = Kron(Array(A), Eye(n))
        if N != length(Mshape)
            n = prod(Mshape[N+1:end])
            B = Kron(Eye(n), B)
        end

    # Case where A is differentiating along the first dimension
    else
        n = prod(Mshape[2:end])
        B = Kron(Eye(n), Array(A))
    end
    return Array(B)
end

function SparseArrays.SparseMatrixCSC(A::DerivativeOperator{T,N}, Mshape) where {T,N}
    # Case where A is not differentiating along the first dimension
    if N != 1
        n = prod(Mshape[1:N-1])
        B = Kron(sparse(A), sparse(I,n,n))
        if N != length(Mshape)
            n = prod(Mshape[N+1:end])
            B = Kron(sparse(I,n,n), B)
        end

    # Case where A is differentiating along the first dimension
    else
        n = prod(Mshape[2:end])
        B = Kron(sparse(I,n,n), sparse(A))
    end
    return sparse(B)
end

function SparseArrays.sparse(A::DerivativeOperator{T,N}, Mshape) where {T,N}
    return SparseMatrixCSC(A,Mshape)
end

function BandedMatrices.BandedMatrix(A::DerivativeOperator{T,N}, Mshape) where {T,N}
    # Case where A is not differentiating along the first dimension
    if N != 1
        n = prod(Mshape[1:N-1])
        B = Kron(BandedMatrix(A), Eye(n))
        if N != length(Mshape)
            n = prod(Mshape[N+1:end])
            B = Kron(Eye(n), B)
        end

    # Case where A is differentiating along the first dimension
    else
        n = prod(Mshape[2:end])
        B = Kron(BandedMatrix(Eye(n)), BandedMatrix(A))
    end
    return BandedMatrix(B)
end

function BlockBandedMatrices.BandedBlockBandedMatrix(A::DerivativeOperator{T,N}, Mshape) where {T,N}
    # Case where A is not differentiating along the first dimension
    if N != 1
        n = prod(Mshape[1:N-1])
        B = Kron(BandedMatrix(A), Eye(n))
        if N != length(Mshape)
            n = prod(Mshape[N+1:end])
            B = Kron(Eye(n), B)
        end

    # Case where A is differentiating along the first dimension
    else
        n = prod(Mshape[2:end])
        B = Kron(BandedMatrix(Eye(n)), BandedMatrix(A))
    end
    return BandedBlockBandedMatrix(B)
end

################################################################################
# Upwind Operator Concretization
################################################################################

# Array Concretizations
# Uniform grid case
function LinearAlgebra.Array(A::DerivativeOperator{T,N,true}, len::Int=A.len) where {T,N}
    L = zeros(T, len, len+2)
    bpc = A.boundary_point_count
    stl = A.stencil_length
    bstl = A.boundary_stencil_length
    coeff   = A.coefficients

    # downwind stencils at low boundary
    downwind_stencils = A.low_boundary_coefs
    # upwind stencils at upper boundary
    upwind_stencils = A.high_boundary_coefs
    # interior stencils
    stencils = A.stencil_coefs

    for i in 1:bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            cur_stencil = stencils
            L[i,i+1:i+stl] = cur_coeff*cur_stencil
        else
            cur_stencil = downwind_stencils[i]
            L[i,1:bstl] = cur_coeff * cur_stencil
        end
    end

    for i in bpc+1:len-bpc
        cur_coeff   = coeff[i]
        cur_stencil = stencils
        cur_stencil = cur_coeff >= 0 ? cur_stencil : ((-1)^A.derivative_order)*reverse(cur_stencil)
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * cur_stencil
        else
            L[i,i-stl+2:i+1] = cur_coeff * cur_stencil
        end
    end

    for i in len-bpc+1:len
        cur_coeff   = coeff[i]
        if cur_coeff < 0
            cur_stencil = stencils
            cur_stencil = ((-1)^A.derivative_order)*reverse(cur_stencil)
            L[i,i-stl+2:i+1] = cur_coeff * cur_stencil
        else
            cur_stencil = upwind_stencils[i-len+bpc]
            L[i,len-bstl+3:len+2] = cur_coeff * cur_stencil
        end
    end
    return L
end

# Non-uniform grid case
function LinearAlgebra.Array(A::DerivativeOperator{T,N,true,M}, len::Int=A.len) where {T,N,M<:AbstractArray{T}}
    L = zeros(T, len, len+2)
    bpc = A.boundary_point_count
    stl = A.stencil_length
    bstl = A.boundary_stencil_length
    coeff   = A.coefficients

    for i in 1:bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * A.low_boundary_coefs[1,i]
        else
            L[i,1:bstl] = cur_coeff * A.low_boundary_coefs[2,i]
        end
    end

    for i in bpc+1:len-bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * A.stencil_coefs[1,i-bpc]
        else
            L[i,i-stl+2:i+1] = cur_coeff * A.stencil_coefs[2,i-bpc]
        end
    end

    for i in len-bpc+1:len
        cur_coeff   = coeff[i]
        if cur_coeff < 0
            L[i,i-stl+2:i+1] = cur_coeff * A.high_boundary_coefs[2,i-len+bpc]
        else
            L[i,len-bstl+3:len+2] = cur_coeff * A.high_boundary_coefs[1,i-len+bpc]
        end
    end
    return L
end

# Sparse Concretizations
# Uniform grid case
function SparseArrays.SparseMatrixCSC(A::DerivativeOperator{T,N,true}, len::Int=A.len) where {T,N}
    L = spzeros(T, len, len+2)
    bpc = A.boundary_point_count
    stl = A.stencil_length
    bstl = A.boundary_stencil_length
    coeff   = A.coefficients

    # downwind stencils at low boundary
    downwind_stencils = A.low_boundary_coefs
    # upwind stencils at upper boundary
    upwind_stencils = A.high_boundary_coefs
    # interior stencils
    stencils = A.stencil_coefs

    for i in 1:bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            cur_stencil = stencils
            L[i,i+1:i+stl] = cur_coeff*cur_stencil
        else
            cur_stencil = downwind_stencils[i]
            L[i,1:bstl] = cur_coeff * cur_stencil
        end
    end

    for i in bpc+1:len-bpc
        cur_coeff   = coeff[i]
        cur_stencil = stencils
        cur_stencil = cur_coeff >= 0 ? cur_stencil : ((-1)^A.derivative_order)*reverse(cur_stencil)
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * cur_stencil
        else
            L[i,i-stl+2:i+1] = cur_coeff * cur_stencil
        end
    end

    for i in len-bpc+1:len
        cur_coeff   = coeff[i]
        if cur_coeff < 0
            cur_stencil = stencils
            cur_stencil = ((-1)^A.derivative_order)*reverse(cur_stencil)
            L[i,i-stl+2:i+1] = cur_coeff * cur_stencil
        else
            cur_stencil = upwind_stencils[i-len+bpc]
            L[i,len-bstl+3:len+2] = cur_coeff * cur_stencil
        end
    end
    return L
end

# Non-uniform grid case
function SparseArrays.SparseMatrixCSC(A::DerivativeOperator{T,N,true,M}, len::Int=A.len) where {T,N,M<:AbstractArray{T}}
    L = spzeros(T, len, len+2)
    bpc = A.boundary_point_count
    stl = A.stencil_length
    bstl = A.boundary_stencil_length
    coeff   = A.coefficients

    for i in 1:bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * A.low_boundary_coefs[1,i]
        else
            L[i,1:bstl] = cur_coeff * A.low_boundary_coefs[2,i]
        end
    end

    for i in bpc+1:len-bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * A.stencil_coefs[1,i-bpc]
        else
            L[i,i-stl+2:i+1] = cur_coeff * A.stencil_coefs[2,i-bpc]
        end
    end

    for i in len-bpc+1:len
        cur_coeff   = coeff[i]
        if cur_coeff < 0
            L[i,i-stl+2:i+1] = cur_coeff * A.high_boundary_coefs[2,i-len+bpc]
        else
            L[i,len-bstl+3:len+2] = cur_coeff * A.high_boundary_coefs[1,i-len+bpc]
        end
    end
    return L
end

# Banded Concretizations
# Uniform grid case
function BandedMatrices.BandedMatrix(A::DerivativeOperator{T,N,true}, len::Int=A.len) where {T,N}
    bpc = A.boundary_point_count
    stl = A.stencil_length
    bstl = A.boundary_stencil_length
    coeff   = A.coefficients
    L = BandedMatrix{T}(Zeros(len, len+2), (stl-2, stl))

    # downwind stencils at low boundary
    downwind_stencils = A.low_boundary_coefs
    # upwind stencils at upper boundary
    upwind_stencils = A.high_boundary_coefs
    # interior stencils
    stencils = A.stencil_coefs

    for i in 1:bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            cur_stencil = stencils
            L[i,i+1:i+stl] = cur_coeff*cur_stencil
        else
            cur_stencil = downwind_stencils[i]
            L[i,1:bstl] = cur_coeff * cur_stencil
        end
    end

    for i in bpc+1:len-bpc
        cur_coeff   = coeff[i]
        cur_stencil = stencils
        cur_stencil = cur_coeff >= 0 ? cur_stencil : ((-1)^A.derivative_order)*reverse(cur_stencil)
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * cur_stencil
        else
            L[i,i-stl+2:i+1] = cur_coeff * cur_stencil
        end
    end

    for i in len-bpc+1:len
        cur_coeff   = coeff[i]
        if cur_coeff < 0
            cur_stencil = stencils
            cur_stencil = ((-1)^A.derivative_order)*reverse(cur_stencil)
            L[i,i-stl+2:i+1] = cur_coeff * cur_stencil
        else
            cur_stencil = upwind_stencils[i-len+bpc]
            L[i,len-bstl+3:len+2] = cur_coeff * cur_stencil
        end
    end
    return L
end


# Non-uniform grid case
function BandedMatrices.BandedMatrix(A::DerivativeOperator{T,N,true,M}, len::Int=A.len) where {T,N,M<:AbstractArray{T}}
    bpc = A.boundary_point_count
    stl = A.stencil_length
    bstl = A.boundary_stencil_length
    coeff   = A.coefficients
    L = BandedMatrix{T}(Zeros(len, len+2), (stl-2, stl))

    for i in 1:bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * A.low_boundary_coefs[1,i]
        else
            L[i,1:bstl] = cur_coeff * A.low_boundary_coefs[2,i]
        end
    end

    for i in bpc+1:len-bpc
        cur_coeff   = coeff[i]
        if cur_coeff >= 0
            L[i,i+1:i+stl] = cur_coeff * A.stencil_coefs[1,i-bpc]
        else
            L[i,i-stl+2:i+1] = cur_coeff * A.stencil_coefs[2,i-bpc]
        end
    end

    for i in len-bpc+1:len
        cur_coeff   = coeff[i]
        if cur_coeff < 0
            L[i,i-stl+2:i+1] = cur_coeff * A.high_boundary_coefs[2,i-len+bpc]
        else
            L[i,len-bstl+3:len+2] = cur_coeff * A.high_boundary_coefs[1,i-len+bpc]
        end
    end
    return L
end

# GhostDerivativeOperator Concretizations
################################################################################
function LinearAlgebra.Array(A::GhostDerivativeOperator{T, E, F},N::Int=A.L.len) where {T,E,F}
    return (Array(A.L,N)*Array(A.Q,A.L.len)[1], Array(A.L,N)*Array(A.Q,A.L.len)[2])
end

function LinearAlgebra.Array(A::GhostDerivativeOperator{T, E, F}, s::NTuple{N,I}) where {T,E,F,N,I<:Int}
    return (Array(A.L, s)*Array(A.Q, s)[1], Array(A.L, s)*Array(A.Q, s)[2])
end


function BandedMatrices.BandedMatrix(A::GhostDerivativeOperator{T, E, F},N::Int=A.L.len) where {T,E,F}
    return (BandedMatrix(A.L,N)*Array(A.Q,A.L.len)[1], BandedMatrix(A.L,N)*Array(A.Q,A.L.len)[2])
end

function BandedMatrices.BandedMatrix(A::GhostDerivativeOperator{T, E, F}, s::NTuple{N,I}) where {T,E,F, N, I<:Int}
    return (BandedMatrix(A.L,s)*Array(A.Q,s)[1], BandedMatrix(A.L,N)*Array(A.Q,s)[2])
end

function SparseArrays.SparseMatrixCSC(A::GhostDerivativeOperator{T, E, F},N::Int=A.L.len) where {T,E,F}
    return (SparseMatrixCSC(A.L,N)*SparseMatrixCSC(A.Q,A.L.len)[1], SparseMatrixCSC(A.L,N)*SparseMatrixCSC(A.Q,A.L.len)[2])
end

function SparseArrays.sparse(A::GhostDerivativeOperator{T, E, F},N::Int=A.L.len) where {T,E,F}
    return SparseMatrixCSC(A,N)
end

################################################################################
# Composite Opeartor Concretizations
################################################################################
Array(L::DiffEqScaledOperator, s) = L.coeff * Array(L.op, s)
Array(L::DiffEqOperatorCombination, s) = sum(Array.(L.ops, fill(s, length(L.ops))))
Array(L::DiffEqOperatorComposition, s) = prod(Array.(reverse(L.ops), fill(s, length(L.ops))))
