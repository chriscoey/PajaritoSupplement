#!/bin/bash
# run from PajaritoSupplement directory

# print julia path that will be used
echo $(which julia)
echo "should be julia-903644385b (v0.6.0)"

# create folder for output text files
mkdir -p output
mkdir -p output/misocp

# run the 5 sets of MISOCP instances for each of the 9 MISOCP solvers
for SOLVER in BONMIN_OA BONMIN_OADIS BONMIN_BB PAJ_CBC_ECOS PAJ_GLPK_ECOS SCIP_MISOCP CPLEX_MISOCP PAJ_CPLEX_MOSEK PAJ_CPLEX_MOSEK_msd
do
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_A.txt
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_B.txt
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_C.txt
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_D.txt
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_E.txt
done

# move the outputs to the MISOCP output folder
mv output/*.txt output/misocp
