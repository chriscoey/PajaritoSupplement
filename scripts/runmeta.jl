
# Usage: runmeta.jl [--nochecktimemem] SOLVERNAME TIMELIMIT MEMORYLIMIT DATAFOLDER INSTANCESET

# Output goes into directory "output". You must create this directory before running the script.

checktimemem = true
if ARGS[1] == "--nochecktimemem"
    checktimemem = false
    shift!(ARGS)
end

solvername = ARGS[1]
tlim = parse(Float64, ARGS[2])
mlim = parse(Int, ARGS[3])
datafolder = ARGS[4]
instfile = ARGS[5]


# Print info and all instances in the set to a META file for the solver
fdmeta = open("output/META.$solvername.$(split(basename(instfile),'.')[1]).txt", "w")

println(fdmeta, "#PKG STATUS#")
Pkg.status(fdmeta)

println(fdmeta, "#SOLVER# $solvername")
println(fdmeta, "#TIMELIMIT# $tlim")
println(fdmeta, "#MEMLIMIT# $mlim")

instancelist = readdlm(instfile)
println(fdmeta, "#INSTANCES#")
for instancename in instancelist
    println(fdmeta, instancename)
end
println(fdmeta)
flush(fdmeta)


# Run each instance one by one
# This only works on Linux because we check the memory use with Linux commands
for instancename in instancelist
    println(fdmeta, "\nstarting instance $instancename...")

    filename = "output/$solvername.$instancename.txt"

    # Try to start a process to run the current instance on
    # If this fails, it won't affect running future instances
    try
        process = spawn(pipeline(`$(Base.JULIA_HOME)/julia scripts/run.jl $solvername $tlim $datafolder $(instancename).cbf.gz`, stdout=filename, stderr=filename, append=true))

        t = time()

        if checktimemem
            sleep(30.0)

            pid = parse(Int, chomp(readline(open("mypid", "r"))))

            while process_running(process)
                if (time() - t) > (tlim + 60*5.0)
                    # Kill if time limit exceeded (some solvers don't respect time limits)
                    kill(process)
                    sleep(1.0)
                    println(fdmeta, "killed by time limit")
                    open(filename, "a") do fd
                        println(fd, "#STATUS# KilledTime")
                    end
                else
                    # Try to kill if memory limit exceeded (some solvers use too much memory and fail)
                    # If this try fails, process has already stopped
                    try
                        memuse = parse(Int, split(readstring(pipeline(`cat /proc/$pid/status`,`grep RSS`)))[2])
                        if memuse > mlim
                            kill(process)
                            sleep(1.0)
                            println(fdmeta, "killed by memory limit")
                            open(filename, "a") do fd
                                println(fd, "#STATUS# KilledMemory")
                            end
                        end
                    end
                end
                sleep(1.0)
            end
        else
            wait(process)
        end

        println(fdmeta, "...took $(time() - t) seconds")
    catch e
        println(fdmeta, "...process error: $e")
    end

    flush(fdmeta)
end

close(fdmeta)
