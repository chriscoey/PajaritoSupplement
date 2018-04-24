using Plots
pgfplots()

import NaNMath
# import BenchmarkProfiles

# Customized performance_profile method, derived from BenchmarkProfiles.jl
# Copyright (c) 2016: Dominique Orban.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

function performance_profile(T0::Array{Float64,2}, labels::Vector{String}; logscale::Bool=true, title::String="", ymax = 1.1, xmax = NaN, linewidth=1, kwargs...)

    T0[isinf.(T0)] = NaN
    T0[T0 .< 0] = NaN

    # Remove instances for which all solvers have NaN
    T = T0[.!(isnan.(T0[:,1]) .& isnan.(T0[:,2])), :]

    # Number of instances and number of solvers
    (np, ns) = size(T)

    # Minimal (i.e., best) performance per solver
    minperf = mapslices(NaNMath.minimum, T, 2)

    # Compute ratios and divide by smallest element in each row
    r = zeros(np, ns)
    for p = 1 : np
        r[p, :] = T[p, :] / minperf[p]
    end

    logscale && (r = log2.(r))
    max_ratio = NaNMath.maximum(r)

    # Replace failures with twice the max_ratio and sort each column of r
    failures = isnan.(r)
    r[failures] = 2 * max_ratio
    r = sort(r, 1)

    (np, ns) = size(r)

    ratios = [r; 2.0 * max_ratio * ones(1, ns)]
    xs = collect(1:np+1)/np
    if length(labels) == 0
        labels = [@sprintf("column %d", col) for col = 1 : ns]
    end

    profile = Plots.plot(; kwargs...)
    for s = 1:ns
        Plots.plot!(ratios[:, s], xs, t=:steppost, label=labels[s], linewidth=linewidth)
    end
    if isfinite(xmax)
        Plots.xlims!(logscale ? 0.0 : 1.0, xmax)
    else
        Plots.xlims!(logscale ? 0.0 : 1.0, 1.1 * max_ratio)
    end
    Plots.ylims!(0, ymax)
    Plots.xlabel!("\$F\$" * (logscale ? " (log scale)" : ""))
    Plots.ylabel!("\$P\$")
    Plots.title!(title)

    return profile
end
