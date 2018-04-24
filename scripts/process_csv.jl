using DataFrames, NamedArrays
import DocOpt
using JLD

doc = """CSV Process Utility

Usage:
  process_csv.jl check <csvfile> [--exclude=<excludefile>]
  process_csv.jl statuscounts <csvfile> <csvfileout> [--exclude=<excludefile>] [--bestof=<list>]...
  process_csv.jl geomeans <csvfile> [--exclude=<excludefile>] [--bestof=<list>]...
  process_csv.jl perfprofile <csvfile> <output_jld> <solver>... [--exclude=<excludefile>] [--bestof=<list>]...
  process_csv.jl -h | --help

Options:
  -h --help               Show this screen.
  --exclude=<excludefile> A list of runs to exclude.
  --bestof=<list>         Create an artificial solver by taking the best of multiple solvers. Format: "A B C" creates a new solver A from best of B and C.
"""

arguments = DocOpt.docopt(doc)

# process the csv produced by process_output.jl
results = readtable(arguments["<csvfile>"])
println()


# file listing manually excluded results
# format by line: solver instance ignored comment
# example: PAJ_CPLEX_MOSEK clay0304h.cbf # CPLEX gave wrong answer
if isa(arguments["--exclude"], String)
    excluded = [split(strip(l))[1:2] for l in split(readstring(arguments["--exclude"]),'\n') if strip(l) != ""]
else
    excluded = []
end

function isexcluded(solver, inst)
    for k in 1:length(excluded)
        if excluded[k][1] == solver && excluded[k][2] == inst
            return true
        end
    end
    return false
end

# exclude any in the exclude file
for i in 1:size(results,1)
    if isexcluded(results[i, :solver], results[i, :instance])
        results[i, :newstatus] = "excl"
    end
end


for solverlist in arguments["--bestof"]
    newsolver = split(solverlist)[1]
    best_of_solvers = split(solverlist)[2:end]
    newrows = []
    for rowlist in groupby(results, :instance)
        besttime = Inf
        beststatus = "blank"
        inst = rowlist[1, :instance]
        for i in 1:size(rowlist, 1)
            if rowlist[i, :solver] in best_of_solvers
                if rowlist[i, :newstatus] == "conv"
                    besttime = min(besttime, rowlist[i, :total_time])
                    beststatus = "conv"
                elseif rowlist[i, :newstatus] == "lim"
                    if beststatus != "conv"
                        besttime = min(besttime, rowlist[i, :total_time])
                        beststatus = "lim"
                    end
                end
            end
        end
        newrow = Dict{Symbol,Any}(n => rowlist[1, n] for n in names(results))
        newrow[:instance] = inst
        newrow[:solver] = newsolver
        newrow[:newstatus] = beststatus
        newrow[:total_time] = besttime
        push!(newrows, newrow)
    end
    for r in newrows
        push!(results, r)
    end
end


conv_runs = results[results[:newstatus] .== "conv", :]

if arguments["check"]
    # check for disagreements in objective value
    println("Objective disagreements")
    for optval_by_instance in groupby(conv_runs, :instance)
        first_optval = optval_by_instance[1, :objval]
        sense = optval_by_instance[1, :sense]
        inst = optval_by_instance[1, :instance]
        for i in 2:size(optval_by_instance, 1)
            solver = optval_by_instance[i, :solver]
            optval = optval_by_instance[i, :objval]
            if abs(optval - first_optval)/(abs(first_optval) + 1e-5) > 1e-4
                println()
                println("$inst (sense = $sense)")
                show(optval_by_instance[:,[:solver, :objval, :objbound]])
                println()
                break
            end
        end
    end

    # # check for duplicated runs
    # for g1 in groupby(results, :instance)
    #     for g2 in groupby(g1, :solver)
    #         if size(g2,1) > 1
    #             s = g2[1, :solver]
    #             inst = g2[1, :instance]
    #             println("Multiple results for solver $s instance $inst")
    #         end
    #     end
    # end


elseif arguments["statuscounts"]
    # status counts by solver
    statuses = sort(collect(unique(results[:newstatus])))
    all_solvers = sort(collect(unique(results[:solver])))
    status_table = NamedArray(zeros(Int, length(all_solvers), length(statuses)+1))
    setnames!(status_table, all_solvers, 1)
    setnames!(status_table, [statuses; "Total"], 2)
    for i in 1:size(results,1)
        status_table[results[i, :solver], results[i, :newstatus]] += 1
        status_table[results[i, :solver], "Total"] += 1
    end

    df2 = DataFrame(convert(Array, status_table))
    names!(df2, convert(Vector{Symbol}, names(status_table,2)))
    df2[:solver] = names(status_table, 1)
    writetable(arguments["<csvfileout>"], df2)


elseif arguments["geomeans"]
    function shifted_geomean(table, field, shift, groupby)
        solvers = unique(table[groupby])
        sum_by = Dict(g => 0.0 for g in solvers)
        counter_by = Dict(g => 0 for g in solvers)
        # prod(x_i + s)^(1/n) - s
        # compute prod(x_i+s)^(1/n) as
        # exp(sum(log(x_i+s))/n)
        for i in 1:size(table, 1)
            if ismissing(table[i, field])
                continue
            end
            sum_by[table[i, groupby]] += log(table[i, field] + shift)
            counter_by[table[i, groupby]] += 1
        end
        for g in solvers
            r = exp(sum_by[g]/counter_by[g]) - shift
            if !isnan(r)
                @printf("%50s %f\n", g, r)
                # println("$g $r")
            end
        end
    end

    timeshift = 10.0
    itershift = 1
    nodeshift = 10

    # set any missing times to time limit
    for i in 1:size(results, 1)
        if ismissing(results[i, :total_time])
            results[i, :total_time] = results[i, :timelimit]
        else
            @assert !isnan(results[i, :total_time]) && results[i, :total_time] > 0
        end
    end

    all_solvers = unique(results[:solver])
    all_conv = []
    for g1 in groupby(conv_runs, :instance)
        hassolver = falses(length(all_solvers))
        for i in 1:size(g1, 1)
            solver = g1[i, :solver]
            idx = findnext(all_solvers, solver, 1)
            hassolver[idx] = true
        end
        if sum(hassolver) == length(all_solvers)
            push!(all_conv, g1[1, :instance])
        end
    end

    # subset of runs where all solvers converged
    runs_all_conv = conv_runs[find(t-> t in all_conv, conv_runs[:instance]), :]

    println("$(length(all_conv)) instances solved optimally by all solvers:\n")
    println(all_conv)
    println()

    println("\nShifted ($timeshift) geomean of solve time...")
    println("\n...on all (before termination)")
    shifted_geomean(results, :total_time, timeshift, :solver)
    println("\n...on conv by this solver")
    shifted_geomean(conv_runs, :total_time, timeshift, :solver)
    println("\n...on conv by all solvers")
    shifted_geomean(runs_all_conv, :total_time, timeshift, :solver)
    println()

    println("\nShifted ($itershift) geomean of conic subproblem count...")
    println("\n...on all (before termination)")
    shifted_geomean(results, :conic_count, itershift, :solver)
    println("\n...on conv by this solver")
    shifted_geomean(conv_runs, :conic_count, itershift, :solver)
    println("\n...on conv by all solvers")
    shifted_geomean(runs_all_conv, :conic_count, itershift, :solver)
    println()

    println("\nShifted ($itershift) geomean of iteration count...")
    println("\n...on all (before termination)")
    shifted_geomean(results, :iter_count, itershift, :solver)
    println("\n...on conv by this solver")
    shifted_geomean(conv_runs, :iter_count, itershift, :solver)
    println("\n...on conv by all solvers")
    shifted_geomean(runs_all_conv, :iter_count, itershift, :solver)
    println()

    println("\nShifted ($nodeshift) geomean of node count...")
    println("\n...on all (before termination)")
    shifted_geomean(results, :node_count, nodeshift, :solver)
    println("\n...on conv by this solver")
    shifted_geomean(conv_runs, :node_count, nodeshift, :solver)
    println("\n...on conv by all solvers")
    shifted_geomean(runs_all_conv, :node_count, nodeshift, :solver)
    println()

elseif arguments["perfprofile"]
    solvers = arguments["<solver>"]

    # need a table of [time] X [solver] where each row is a solver
    time_rows = []
    itndcount_rows = []
    instance_names = String[]
    for by_instance in groupby(conv_runs, :instance)
        time_row = fill(Inf, length(solvers))
        itndcount_row = fill(Inf, length(solvers))
        for i in 1:size(by_instance, 1)
            push!(instance_names, by_instance[1, :instance])
            if by_instance[i, :newstatus] == "conv"
                whichsolver = indexin([by_instance[i, :solver]], solvers)[1]
                if whichsolver != 0
                    time_row[whichsolver] = by_instance[i, :total_time]
                    if !ismissing(by_instance[i, :iter_count])
                        itndcount_row[whichsolver] = by_instance[i, :iter_count]
                    else
                        @assert !ismissing(by_instance[i, :node_count])
                        itndcount_row[whichsolver] = by_instance[i, :node_count]
                    end
                end # else not plotting this solver
            end # else not solved, Inf by default
        end
        push!(time_rows, time_row')
        push!(itndcount_rows, itndcount_row')
    end
    time_mat = vcat(time_rows...)
    itndcount_mat = vcat(itndcount_rows...)

    @assert endswith(arguments["<output_jld>"],".jld")
    save(arguments["<output_jld>"], "time_table", time_mat, "itndcount_table", itndcount_mat, "solvers", solvers, "instance_names", instance_names)
end
println()
