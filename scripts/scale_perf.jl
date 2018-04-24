using JLD

include("perfplots.jl")

timeshift = 10.0
itershift = 1
nodeshift = 10

# produced by process_csv.jl in perfprofile mode
jldsource = joinpath(dirname(@__FILE__),"..",ARGS[1],"scale_perf.jld")

d = load(jldsource)
solvers = d["solvers"]
@assert solvers == ["PAJ_Gurobi_MOSEK_noscale_subponly_noinit","PAJ_Gurobi_MOSEK_msd_noscale_subponly_noinit","PAJ_Gurobi_MOSEK_scale_subponly_noinit","PAJ_Gurobi_MOSEK_msd_scale_subponly_noinit"]
instance_names = d["instance_names"]

iter_solvers = solvers[[1,3]]
iter_time_table = d["time_table"][:,[1,3]] + timeshift
iter_iter_table = d["itndcount_table"][:,[1,3]] + itershift

msd_solvers = solvers[[2,4]]
msd_time_table = d["time_table"][:,[2,4]] + timeshift
msd_node_table = d["itndcount_table"][:,[2,4]] + nodeshift


performance_profile(iter_time_table, iter_solvers, logscale=false, ymax=1.0, xmax=2, linewidth=3)
Plots.savefig(joinpath(dirname(@__FILE__),"..",ARGS[1],"scale_iter_time.tex"))

performance_profile(iter_iter_table, iter_solvers, logscale=false, ymax=1.0, xmax=2, linewidth=3)
Plots.savefig(joinpath(dirname(@__FILE__),"..",ARGS[1],"scale_iter_iters.tex"))

performance_profile(msd_time_table, msd_solvers, logscale=false, ymax=1.0, xmax=2, linewidth=3)
Plots.savefig(joinpath(dirname(@__FILE__),"..",ARGS[1],"scale_msd_time.tex"))

performance_profile(msd_node_table, msd_solvers, logscale=false, ymax=1.0, xmax=6, linewidth=3)
Plots.savefig(joinpath(dirname(@__FILE__),"..",ARGS[1],"scale_msd_nodes.tex"))
