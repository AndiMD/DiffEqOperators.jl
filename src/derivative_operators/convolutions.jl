# mul! done by convolutions
function LinearAlgebra.mul!(x_temp::AbstractVector{T}, A::DerivativeOperator, x::AbstractVector{T}) where T<:Real
    convolve_BC_left!(x_temp, x, A)
    convolve_interior!(x_temp, x, A)
    convolve_BC_right!(x_temp, x, A)
end

################################################

# Against a standard vector, assume already padded and just apply the stencil
function convolve_interior!(x_temp::AbstractVector{T}, x::AbstractVector{T}, A::DerivativeOperator) where {T<:Real}
    @assert length(x_temp)+2 == length(x)
    stencil = A.stencil_coefs
    coeff   = A.coefficients
    # Upwind operators have a non-centred stencil
    if use_winding(A)
        mid = 1 + A.stencil_length%2
    else
        mid = div(A.stencil_length,2)
    end
    for i in (1+A.boundary_point_count) : (length(x_temp)-A.boundary_point_count)
        xtempi = zero(T)
        cur_stencil = eltype(stencil) <: AbstractVector ? stencil[i-A.boundary_point_count] : stencil
        cur_coeff   = typeof(coeff)   <: AbstractVector ? coeff[i] : coeff isa Number ? coeff : true
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(cur_stencil) : cur_stencil
        for idx in 1:A.stencil_length
            x_idx = use_winding(A) && cur_coeff < 0 ? x[i + mid - idx] : x[i - mid + idx]
            xtempi += cur_coeff * cur_stencil[idx] * x_idx
            # @show i, idx, cur_stencil[idx], i-mid+idx, x[i-mid+idx]
        end
        x_temp[i] = xtempi
    end
end

function convolve_BC_left!(x_temp::AbstractVector{T}, x::AbstractVector{T}, A::DerivativeOperator) where {T<:Real}
    stencil = A.low_boundary_coefs
    coeff   = A.coefficients
    for i in 1 : A.boundary_point_count
        cur_stencil = stencil[i]

        if cur_stencil == []
            cur_stencil = A.stencil_coefs
        end

        cur_coeff   = typeof(coeff)   <: AbstractVector ? coeff[i] : coeff isa Number ? coeff : true
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(cur_stencil) : cur_stencil
        xtempi = cur_coeff*stencil[i][1]*x[1]
        for idx in 2:A.boundary_stencil_length
            xtempi += cur_coeff * cur_stencil[idx] * x[idx]
        end
        x_temp[i] = xtempi
    end
end

function convolve_BC_right!(x_temp::AbstractVector{T}, x::AbstractVector{T}, A::DerivativeOperator) where {T<:Real}
    stencil = A.high_boundary_coefs
    coeff   = A.coefficients
    N       = length(x)
    L       = A.boundary_stencil_length
    for i in 1 : A.boundary_point_count
        cur_stencil = stencil[i]

        if cur_stencil == []
            cur_stencil = A.stencil_coefs
        end

        cur_coeff   = typeof(coeff)   <: AbstractVector ? coeff[i] : coeff isa Number ? coeff : true
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(cur_stencil) : cur_stencil
        # cs = cur_stencil*(A.dx^A.derivative_order)
        xtempi = zero(T)
        for idx in 1:(A.boundary_stencil_length)
            # @show idx, N-L+idx, cs[idx], x[N-L+idx]
            xtempi += cur_coeff * cur_stencil[idx] * x[N-L+idx]
        end
        # @show xtempi*(1/(A.dx^A.derivative_order))
        x_temp[end-A.boundary_point_count+i] = xtempi
    end
end

###########################################

# Against A BC-padded vector, specialize the computation to explicitly use the left, right, and middle parts
function convolve_interior!(x_temp::AbstractVector{T}, _x::BoundaryPaddedVector, A::DerivativeOperator) where {T<:Real}
    @assert length(x_temp) == length(_x.u)
    stencil = A.stencil_coefs
    coeff   = A.coefficients
    # Upwind operators have a non-centred stencil
    if use_winding(A)
        mid = 1 + A.stencil_length%2
    else
        mid = div(A.stencil_length,2)
    end

    # Just do the middle parts
    for i in (1+A.boundary_point_count) : (length(x_temp)-A.boundary_point_count)
        xtempi = zero(T)
        cur_stencil = eltype(stencil) <: AbstractVector ? stencil[i-A.boundary_point_count] : stencil
        cur_coeff   = typeof(coeff)   <: AbstractVector ? coeff[i-A.boundary_point_count] : coeff isa Number ? coeff : true
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(cur_stencil) : cur_stencil
        @inbounds for idx in 1:A.stencil_length
            # @show i, idx, cur_stencil[idx], i-mid+idx, x[i-mid+idx]
            x_idx = use_winding(A) && cur_coeff < 0 ? _x[i + mid - idx] : _x[i - mid + idx]
            xtempi += cur_coeff * cur_stencil[idx] * x_idx
        end
        x_temp[i] = xtempi
    end
end

function convolve_BC_left!(x_temp::AbstractVector{T}, _x::BoundaryPaddedVector, A::DerivativeOperator) where {T<:Real}
    stencil = A.low_boundary_coefs
    coeff   = A.coefficients
    for i in 1 : A.boundary_point_count
        cur_stencil = stencil[i]

        if cur_stencil == []
            cur_stencil = A.stencil_coefs
        end

        cur_coeff   = typeof(coeff)   <: AbstractVector ? coeff[i] : coeff isa Number ? coeff : true
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(cur_stencil) : cur_stencil

        # need to account for x.l in first interior
        xtempi = cur_coeff*cur_stencil[1]*_x.l
        @inbounds for idx in 2:A.boundary_stencil_length
            xtempi += cur_coeff * cur_stencil[idx] * _x.u[idx-1]
        end
        x_temp[i] = xtempi
    end

    # DO WE REALLY NEED IT?
    # # need to account for x.l in first interior
    # mid = div(A.stencil_length,2) + 1
    # x = _x.u
    # i = 1 + A.boundary_point_count
    # xtempi = zero(T)
    # cur_stencil = eltype(A.stencil_coefs) <: AbstractVector ? A.stencil_coefs[i-A.boundary_point_count] : A.stencil_coefs
    # cur_coeff   = typeof(coeff)   <: AbstractVector ? coeff[i-A.boundary_point_count] : coeff isa Number ? coeff : true
    # cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(cur_stencil) : cur_stencil
    # xtempi = cur_coeff*cur_stencil[1]*_x.l
    # @inbounds for idx in 2:A.stencil_length
    #     xtempi += cur_coeff * cur_stencil[idx] * x[(i-1) - (mid-idx) + 1]
    # end
    # x_temp[i] = xtempi

end

function convolve_BC_right!(x_temp::AbstractVector{T}, _x::BoundaryPaddedVector, A::DerivativeOperator) where {T<:Real}
    stencil = A.high_boundary_coefs
    coeff   = A.coefficients
    N = length(_x.u)
    bpc = A.boundary_point_count
    # need to account for _x.r in last interior convolution
    mid = div(A.stencil_length,2) + 1
    x = _x.u
    i = length(x_temp)-A.boundary_point_count
    L = A.boundary_stencil_length

    bc_start = N - bpc + 1
    for i in 1 : A.boundary_point_count
        cur_stencil = stencil[i]
        cur_coeff   = typeof(coeff)   <: AbstractVector ? coeff[bc_start + i] : coeff isa Number ? coeff : true
        xtempi = cur_coeff*cur_stencil[end]*_x.r
        cur_stencil = use_winding(A) && cur_coeff < 0 ? reverse(cur_stencil) : cur_stencil

        @inbounds for idx in A.stencil_length:-1:1
            # @show idx, N-L+idx, cs[idx], x[N-L+idx]
            xtempi += cur_coeff * cur_stencil[end-idx] * _x.u[end-idx+1]
        end
        # @inbounds for idx in 1:A.boundary_stencil_length-1
        #     xtempi += cur_coeff * cur_stencil[idx] * _x.u[end-L+idx+1]
        # end

        x_temp[bc_start + i - 1] = xtempi
    end
end