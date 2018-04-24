
# Usage: run.jl SOLVERNAME TIMELIMIT DATAFOLDER INSTANCENAME

using ConicBenchmarkUtilities
using Pajarito
using ConicNonlinearBridge


# Print with full precision
function vec_to_string(v)
    terms = String[]
    for x in v
        b = IOBuffer()
        show(b, x)
        push!(terms, String(take!(b)))
    end
    return string("[",join(terms,","),"]")
end


function solveprint(instance, solver)
    # Convert from cbf to our conic format
    (c, A, b, con_cones, var_cones, vartypes, sense, objoffset) = cbftompb(instance)
    if sense == :Max
        scale!(c, -1)
    end

    # Load, solve, and time
    m = MathProgBase.ConicModel(solver)
    timeall = time()
    MathProgBase.loadproblem!(m, c, A, b, con_cones, var_cones)
    if !all(t->t==:Cont, vartypes)
        MathProgBase.setvartype!(m, vartypes)
    end
    MathProgBase.optimize!(m)
    timeall = time() - timeall
    timesolver = MathProgBase.getsolvetime(m)
    status = MathProgBase.status(m)

    x = []
    try
        x = MathProgBase.getsolution(m)
    end

    objval = NaN
    objbound = NaN
    nodecount = NaN
    try
        objval = MathProgBase.getobjval(m)
        if sense == :Max
            objval = -objval
        end
        objval += objoffset
    end
    try
        objbound = MathProgBase.getobjbound(m)
        if sense == :Max
            objbound = -objbound
        end
        objbound += objoffset
    end
    try
        nodecount = MathProgBase.getnodecount(m)
    end

    println("#STATUS# $status")
    println("#OBJVAL# $objval")
    println("#OBJBOUND# $objbound")
    println("#NODECOUNT# $nodecount")
    println("#TIMESOLVER# $timesolver")
    println("#TIMEALL# $timeall")
    println("#SOLUTION# $(vec_to_string(x))")
end


solvermap = Dict(
    # BONMIN
    "BONMIN_OA" =>
    (["AmplNLWriter"], quote ConicNLPWrapper(
    nlp_solver=BonminNLSolver(["bonmin.algorithm=\"B-OA\"", "bonmin.time_limit=$tlim", "halt_on_ampl_error=yes", "bonmin.allowable_fraction_gap=$rgap", "bonmin.oa_log_level=1", "bonmin.bb_log_level=1"]),
    disaggregate_soc=false,
    ) end),

    "BONMIN_OADIS" =>
    (["AmplNLWriter"], quote ConicNLPWrapper(
    nlp_solver=BonminNLSolver(["bonmin.algorithm=\"B-OA\"", "bonmin.time_limit=$tlim", "halt_on_ampl_error=yes", "bonmin.allowable_fraction_gap=$rgap", "bonmin.oa_log_level=1", "bonmin.bb_log_level=1"]),
    disaggregate_soc=true,
    ) end),

    "BONMIN_BB" =>
    (["AmplNLWriter"], quote ConicNLPWrapper(
    nlp_solver=BonminNLSolver(["bonmin.algorithm=\"B-BB\"", "bonmin.time_limit=$tlim", "halt_on_ampl_error=yes", "bonmin.allowable_fraction_gap=$rgap", "bonmin.oa_log_level=1", "bonmin.bb_log_level=1"]),
    disaggregate_soc=false,
    ) end),


    # SCIP
    "SCIP_MISOCP" =>
    (["SCIP"], quote SCIPSolver(
    "limits/gap", rgap, "numerics/feastol", tol_feas, "limits/time", tlim,
    ) end),


    # CPLEX
    "CPLEX_MISOCP" =>
    (["CPLEX"], quote CplexSolver(
    CPX_PARAM_THREADS=1, CPX_PARAM_TILIM=tlim, CPX_PARAM_SCRIND=1, CPX_PARAM_EPINT=tol_int, CPX_PARAM_EPRHS=tol_feas, CPX_PARAM_EPGAP=rgap,
    ) end),


    # Paj CBC
    "PAJ_CBC_ECOS" =>
    (["Cbc","ECOS"], quote PajaritoSolver(
    mip_solver=CbcSolver(logLevel=0, integerTolerance=tol_int, primalTolerance=tol_feas, ratioGap=tol_gap, check_warmstart=false),
    cont_solver=ECOSSolver(verbose=false, reltol=1e-10, feastol=1e-10, reltol_inacc=1e-5, feastol_inacc=1e-8),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    ) end),

    # Paj GLPK
    "PAJ_GLPK_ECOS" =>
    (["GLPKMathProgInterface","ECOS"], quote PajaritoSolver(
    mip_solver=GLPKSolverMIP(msg_lev=GLPK.MSG_OFF, tol_int=tol_int, tol_bnd=tol_feas, mip_gap=tol_gap, presolve=true),
    cont_solver=ECOSSolver(verbose=false, reltol=1e-10, feastol=1e-10, reltol_inacc=1e-5, feastol_inacc=1e-8),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    ) end),


    # Paj CPLEX MOSEK
    "PAJ_CPLEX_MOSEK" =>
    (["CPLEX","Mosek"], quote PajaritoSolver(
    mip_solver=CplexSolver(CPX_PARAM_THREADS=1, CPX_PARAM_SCRIND=0, CPX_PARAM_EPINT=tol_int, CPX_PARAM_EPRHS=tol_feas, CPX_PARAM_EPGAP=tol_gap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=1, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    ) end),

    "PAJ_CPLEX_MOSEK_msd" =>
    (["CPLEX","Mosek"], quote PajaritoSolver(
    mip_solver=CplexSolver(CPX_PARAM_THREADS=1, CPX_PARAM_SCRIND=1, CPX_PARAM_EPINT=tol_int, CPX_PARAM_EPRHS=tol_feas, CPX_PARAM_EPGAP=rgap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=1, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    mip_solver_drives=true,
    ) end),


    # Paj Gurobi sep only
    "PAJ_Gurobi_sep" =>
    (["Gurobi"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=0, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=tol_gap),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    prim_cuts_only=true, solve_relax=false, solve_subp=false,
    ) end),

    "PAJ_Gurobi_msd_sep" =>
    (["Gurobi"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=1, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=rgap),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    mip_solver_drives=true,
    prim_cuts_only=true, solve_relax=false, solve_subp=false,
    ) end),

    # Paj Gurobi MOSEK
    "PAJ_Gurobi_MOSEK" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=0, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=tol_gap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    ) end),

    "PAJ_Gurobi_MOSEK_msd" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=1, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=rgap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    mip_solver_drives=true,
    ) end),

    # Paj Gurobi MOSEK no init
    "PAJ_Gurobi_MOSEK_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=0, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=tol_gap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    ) end),

    "PAJ_Gurobi_MOSEK_msd_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=1, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=rgap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    mip_solver_drives=true,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    ) end),

    # Paj Gurobi MOSEK subp only, no init
    "PAJ_Gurobi_MOSEK_subponly_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=0, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=tol_gap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    prim_cuts_assist=false,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    ) end),

    "PAJ_Gurobi_MOSEK_msd_subponly_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=1, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=rgap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    mip_solver_drives=true,
    prim_cuts_assist=false,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    ) end),

    # Paj Gurobi MOSEK no disagg, subp only, no init
    "PAJ_Gurobi_MOSEK_nodisagg_subponly_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=0, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=tol_gap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    prim_cuts_assist=false,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    all_disagg=false, soc_disagg=false, sdp_eig=false
    ) end),

    "PAJ_Gurobi_MOSEK_msd_nodisagg_subponly_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=1, Threads=8, IntFeasTol=tol_int, FeasibilityTol=tol_feas, MIPGap=rgap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=tol_feas,
    mip_solver_drives=true,
    prim_cuts_assist=false,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    all_disagg=false, soc_disagg=false, sdp_eig=false
    ) end),

    # Paj Gurobi MOSEK scale, subp only, no init
    # NOTE feas tol is 1e-6
    "PAJ_Gurobi_MOSEK_scale_subponly_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=0, Threads=8, IntFeasTol=tol_int, FeasibilityTol=1e-6, MIPGap=tol_gap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=1e-6,
    prim_cuts_assist=false,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    ) end),

    "PAJ_Gurobi_MOSEK_msd_scale_subponly_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=1, Threads=8, IntFeasTol=tol_int, FeasibilityTol=1e-6, MIPGap=rgap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=1e-6,
    mip_solver_drives=true,
    prim_cuts_assist=false,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    ) end),

    # Paj Gurobi MOSEK noscale, subp only, no init
    # NOTE feas tol is 1e-6
    "PAJ_Gurobi_MOSEK_noscale_subponly_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=0, Threads=8, IntFeasTol=tol_int, FeasibilityTol=1e-6, MIPGap=tol_gap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=1e-6,
    scale_subp_cuts=false,
    prim_cuts_assist=false,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    ) end),

    "PAJ_Gurobi_MOSEK_msd_noscale_subponly_noinit" =>
    (["Gurobi","Mosek"], quote PajaritoSolver(
    mip_solver=Gurobi.GurobiSolver(OutputFlag=1, Threads=8, IntFeasTol=tol_int, FeasibilityTol=1e-6, MIPGap=rgap),
    cont_solver=MosekSolver(LOG=0, NUM_THREADS=8, MSK_DPAR_INTPNT_CO_TOL_REL_GAP=1e-10, MSK_DPAR_INTPNT_CO_TOL_PFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_DFEAS=1e-10, MSK_DPAR_INTPNT_CO_TOL_NEAR_REL=1e3),
    log_level=logl, timeout=tlim, rel_gap=rgap, prim_cut_feas_tol=1e-6,
    mip_solver_drives=true,
    scale_subp_cuts=false,
    prim_cuts_assist=false,
    init_soc_one=false, init_soc_inf=false, init_exp=false, init_sdp_lin=false, init_sdp_soc=false,
    ) end),
)


function getsolver(solvername, tlim, logl, rgap)
    packages, solvername = solvermap[solvername]
    for p in packages
        eval(parse("using $p"))
    end
    return eval(solvername)
end


@assert length(ARGS) >= 3

# Save process ID for runmeta.jl
open("mypid", "w") do fd
    print(fd, getpid())
end

# General options
logl = 3
rgap = 1e-5

# Pajarito MIP solver options
tol_int = 1e-9
tol_feas = 1e-8
tol_gap = 0.

solvername = ARGS[1]
tlim = parse(Float64, ARGS[2])
datafolder = ARGS[3]

# Force solver to compile on a small instance for the solver to avoid measuring compilation time, keep quiet
TT = STDOUT
solver = getsolver(solvername, 60., 3, rgap)
open("/dev/null", "w") do fd
    redirect_stdout(fd)
    instance = readcbfdata(joinpath(datafolder, "compile.cbf.gz"))
    solveprint(instance, solver)
end
redirect_stdout(TT)

instancename = ARGS[4]

# Interpret instance data as cbf
instance = readcbfdata(joinpath(datafolder, instancename))
solver = getsolver(solvername, tlim, logl, rgap)

println("#SOLVERNAME# $solvername")
println("#SOLVER# $solver")
println("#INSTANCE# $instancename")
println("#TIMELIMIT# $tlim")

# Attempt to solve, print solve info
timesolve = time()
try
    solveprint(instance, solver)
catch e
    println("#ERROR# $e")
end
