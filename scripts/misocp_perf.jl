using JLD

include("perfplots.jl")

timeshift = 10.0

# produced by process_csv.jl in perfprofile mode
jldsource = joinpath(dirname(@__FILE__),"..",ARGS[1],"misocp_perf.jld")

d = load(jldsource)
solvers = d["solvers"]
@assert solvers == ["BONMIN","PAJ_CBC_ECOS","PAJ_GLPK_ECOS","SCIP_MISOCP","CPLEX_MISOCP","PAJ_CPLEX_MOSEK","PAJ_CPLEX_MOSEK_msd"]
instance_names = d["instance_names"]

comm_solvers = solvers[[5,7]]
comm_time_table = d["time_table"][:,[5,7]] + timeshift

open_solvers = solvers[[1,2]]
open_time_table = d["time_table"][:,[1,2]] + timeshift


performance_profile(comm_time_table, comm_solvers, logscale=false, ymax=1.0, xmax=8, linewidth=3)
Plots.savefig(joinpath(dirname(@__FILE__),"..",ARGS[1],"misocp_comm_time.tex"))

performance_profile(open_time_table, open_solvers, logscale=false, ymax=1.0, xmax=8, linewidth=3)
Plots.savefig(joinpath(dirname(@__FILE__),"..",ARGS[1],"misocp_open_time.tex"))
