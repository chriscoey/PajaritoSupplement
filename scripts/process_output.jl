using ConicBenchmarkUtilities
using Mosek
using MathProgBase

# Usage: process_output.jl [--noconicsolve] RESULTFOLDERS... OUTPUT.csv

@assert length(ARGS) >= 2
NOCONIC = false
if ARGS[1] == "--noconicsolve"
    NOCONIC = true
    shift!(ARGS)
end
resultfiles = []
for i in 1:length(ARGS)-1
    append!(resultfiles,[joinpath(pwd(),ARGS[i],f) for f in readdir(joinpath(pwd(), ARGS[i]))])
end

fd = open(joinpath(pwd(), ARGS[end]), "w")

# Process into a CSV file with columns:
println(fd,"solver,instance,filename,sense,timelimit,solver_time,total_time,status,newstatus,objval,objbound,calc_objgap,objval_error,validator_status,validator_relobjdiff,iter_count,node_count,conic_count,conic_opt_count,conic_inf_count,relax_status,relax_time,conic_time,mip_time,int_viol,lin_viol,soc_viol,socrot_viol,exp_viol,psd_viol")

# From instance name to file name
function find_instance(name)
    instances = joinpath(dirname(@__FILE__),"..","cbfs")
    try
        match = "$name.*"
        f = readstring(`find $instances -name $match`)
        if length(split(f,"\n")) == 2
            return convert(String,chomp(f))
        end
    end
    return ""
end

function make_smat(svec::Vector{Float64})
    dim = Int(sqrt(1/4+2length(svec)) - 1/2)
    smat = Array{Float64}(dim,dim)
    k = 1

    for i in 1:dim, j in i:dim
        if i == j
            smat[i,j] = svec[k]
        else
            smat[i,j] = (1/sqrt(2))*svec[k]
        end
        k += 1
    end

    return smat
end

function violation_cone(subvec,cone)
    if cone == :Zero
        return :Linear, maximum(abs, subvec)
    elseif cone == :NonNeg
        return :Linear, -minimum(min.(subvec, 0.))
    elseif cone == :NonPos
        return :Linear, maximum(max.(subvec, 0.))
    elseif cone == :SOC
        return :SOC, max(0., vecnorm(subvec[2:end]) - subvec[1])
    elseif cone == :SOCRotated
        # (y,z,x) in RSOC <=> (sqrt2inv*(y+z),sqrt2inv*(-y+z),x) in SOC
        return :SOCRotated, max(0., sqrt(1/2*(subvec[1] - subvec[2])^2 + sum(abs2, subvec[3:end])) - 1/sqrt(2)*(subvec[1] + subvec[2]))
    elseif cone == :ExpPrimal
        return :Exp, max(subvec[2]*exp(subvec[1]/subvec[2]) - subvec[3], 0)
    elseif cone == :Free
        return :Linear, 0.0
    elseif cone == :SDP
        smat = make_smat(subvec)
        return :PSD, -min(eigmin(Symmetric(smat)), 0.0)
    else
        error("Unrecognized cone $cone")
    end
end


function compute_viols(dat, solution)
    c, A, b, con_cones, var_cones, vartypes, sense, objoffset = cbftompb(dat)

    if length(solution) > length(c)
        println("Solution is too long")
    end
    @assert length(solution) >= length(c)
    solution = solution[1:length(c)]
    objval = dot(c,solution)

    y = b - A*solution
    lin_viol = -Inf
    soc_viol = -Inf
    socrot_viol = -Inf
    exp_viol = -Inf
    psd_viol = -Inf
    for (cones,x) in [(var_cones,solution),(con_cones,y)]
        for (cone, idx) in cones
            t, viol = violation_cone(x[idx],cone)
            if t == :Linear
                lin_viol = max(lin_viol,viol)
            elseif t == :SOC
                soc_viol = max(soc_viol,viol)
            elseif t == :SOCRotated
                socrot_viol = max(socrot_viol,viol)
            elseif t == :Exp
                exp_viol = max(exp_viol,viol)
            elseif t == :PSD
                psd_viol = max(psd_viol,viol)
            end
        end
    end

    int_viol = 0.0
    for i in 1:length(vartypes)
        if vartypes[i] == :Int || vartypes[i] == :Bin
            int_viol = max(int_viol, abs(solution[i] - round(solution[i])))
        end
    end

    return objval, lin_viol, soc_viol, socrot_viol, exp_viol, psd_viol, int_viol
end

function validate_with_conic_solver(dat, solution)
    c, A, b, con_cones, var_cones, vartypes, sense, objoffset = cbftompb(dat)
    @assert objoffset == 0.0

    if sense == :Max
        c = -c
    end

    con_cones = copy(con_cones)
    I_eq = Int[]
    J_eq = Int[]
    b_eq = Float64[]
    intcount = 1
    for i in 1:length(vartypes)
        if vartypes[i] == :Int
            push!(I_eq,intcount)
            intcount += 1
            push!(J_eq,i)
            push!(b_eq, round(solution[i]))
        else
            @assert vartypes[i] == :Cont
        end
    end
    con_cones = vcat(con_cones, (:Zero,size(A,1)+1:size(A,1)+intcount-1))
    A = vcat(A, sparse(I_eq,J_eq,ones(length(I_eq)),length(I_eq),length(c)))
    b = vcat(b, b_eq)

    m = MathProgBase.ConicModel(MosekSolver(LOG=0))
    MathProgBase.loadproblem!(m, c, A, b, con_cones, var_cones)
    MathProgBase.optimize!(m)
    status = MathProgBase.status(m)
    if status == :Optimal
        objval = MathProgBase.getobjval(m)
        if sense == :Max
            objval *= -1
        end
    else
        objval = NaN
    end
    return status, objval
end

for (cnt, filename) in enumerate(resultfiles)
    if startswith(basename(filename), ".") || contains(filename,"META")
        continue
    end
    println("$cnt of $(length(resultfiles)): $(basename(filename))")

    solver = split(basename(filename),".")[1]
    # instance name may have '.' in it
    instance = join(split(basename(filename),".")[2:end-1],".")
    instance = string(instance,".cbf")

    timelimit = ""
    status = ""
    objval = Inf
    objbound = -Inf
    solver_time = ""
    total_time = ""
    node_count = ""
    lin_viol = ""
    soc_viol = ""
    socrot_viol = ""
    exp_viol = ""
    psd_viol = ""
    int_viol = ""
    conic_count = ""
    conic_opt_count = ""
    conic_inf_count = ""
    relax_status = ""
    conic_time = ""
    relax_time = ""
    mip_time = ""
    iter_count = ""
    solution = []

    for line in eachline(filename)
        if startswith(line, "#SOLVERNAME#")
            @assert solver == split(line)[2]
        elseif startswith(line, "#INSTANCE#")
            inst = split(line)[2]
            if endswith(inst, ".gz")
                @assert instance == inst[1:end-3]
            else
                @assert instance == inst
            end
        elseif startswith(line, "#TIMELIMIT#")
            timelimit = split(line)[2]
        elseif startswith(line, "#STATUS#")
            status = split(line)[2]
        elseif startswith(line, "#OBJVAL#")
            objval = parse(Float64,split(line)[2])
        elseif startswith(line, "#OBJBOUND#")
            objbound = parse(Float64,split(line)[2])
        elseif startswith(line, "#TIMESOLVER#")
            solver_time = split(line)[2]
        elseif startswith(line, "#TIMEALL#")
            total_time = split(line)[2]
        elseif startswith(line, "#NODECOUNT#")
            node_count = split(line)[2]
        elseif startswith(line, "#SOLUTION#")
            solutionvec = split(line)[2]
            if startswith(solutionvec,'[') && endswith(solutionvec,']') && !startswith(solutionvec, "[]")
                solution = [parse(Float64,x) for x in split(solutionvec[2:end-1],',')]
            end
        elseif startswith(line, " - Iterations           =")
            iter_count = split(line)[4]
        elseif startswith(line, " -- Conic subproblems   =")
            conic_count = split(line)[5]
        elseif startswith(line, " --- Optimal            =")
            conic_opt_count = split(line)[4]
        elseif startswith(line, " --- Infeasible         =")
            conic_inf_count = split(line)[4]
        elseif startswith(line, " - Relaxation status    =")
            relax_status = split(line)[5]
        elseif startswith(line, " -- Solve subproblems   =")
            conic_time = split(line)[5]
        elseif startswith(line, " -- Solve relaxation    =")
            relax_time = split(line)[5]
        elseif startswith(line, " -- Solve MIP models    =") || startswith(line, " -- MIP solver driving  =")
            mip_time = split(line)[6]
        end
    end

    instancefile = find_instance(instance)
    dat = readcbfdata(instancefile)
    sense = string(dat.sense)
    validator_status = ""
    validator_objval = ""
    validator_relobjdiff = ""
    objval_error = ""
    calc_objgap = ""

    # Decide status classification (more can later be excluded if objvals disagree)
    newstatus = ""

    if length(solution) > 0 && all(isfinite,solution)
        objval_sol, lin_viol, soc_viol, socrot_viol, exp_viol, psd_viol, int_viol = compute_viols(dat,solution)

        objval_error = abs(objval_sol - objval)/(abs(objval) + 1e-5)

        if startswith(solver, "BONMIN")
            if status == "Optimal"
                # Have to trust bonmin because cannot query objectivebound
                calc_objgap = 1e-5
            else
                calc_objgap = Inf
            end
        else
            calc_objgap = (objval_sol - objbound) / (abs(objval_sol) + 1e-5)
        end

        if !NOCONIC
            # use conic solver to calculate objval
            validator_status, validator_objval = validate_with_conic_solver(dat, solution)
            validator_relobjdiff = abs(objval_sol - validator_objval)/(abs(objval_sol) + 1e-5)
        end

        if status == "UserLimit" || status == "Suboptimal"
            if parse(Float64, solver_time) > 0.9*parse(Float64, timelimit)
                newstatus = "lim"
            else
                newstatus = "err"
            end
        elseif lin_viol > 1e-6 || soc_viol > 1e-5 || socrot_viol > 1e-5 || exp_viol > 1e-5 || psd_viol > 1e-4 || int_viol > 1e-6
            newstatus = "excl"
        elseif objval_error > 1e-8
            newstatus = "excl"
        elseif !NOCONIC && (validator_status == "Infeasible" || (isfinite(validator_relobjdiff) && validator_relobjdiff > 1e-5))
            newstatus = "excl"
        elseif status == "Optimal"
            if -1e-3 < calc_objgap < 1.05e-5
                newstatus = "conv"
            else
                newstatus = "excl"
            end
        end
    elseif status == "UserLimit"
        newstatus = "lim"
    end

    if status == "Infeasible"
        newstatus = "excl"
    elseif status == "KilledTime" || status == "KilledMemory"
        newstatus = "lim"
    elseif status == "" || status == "Error" || status == "FailedMIP" || status == "UnboundedOA" || status == "FailedOA"
        newstatus = "err"
    end

    if newstatus == ""
        error("new status not handled for $solver $instance with solver status $status")
    end

    println(fd,"$solver,$instance,$(basename(filename)),$sense,$timelimit,$solver_time,$total_time,$status,$newstatus,$objval,$objbound,$calc_objgap,$objval_error,$validator_status,$validator_relobjdiff,$iter_count,$node_count,$conic_count,$conic_opt_count,$conic_inf_count,$relax_status,$relax_time,$conic_time,$mip_time,$int_viol,$lin_viol,$soc_viol,$socrot_viol,$exp_viol,$psd_viol")
end

close(fd)
