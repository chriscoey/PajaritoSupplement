#!/bin/bash
# run from PajaritoSupplement directory

# set julia binary location
JULIA=/home/coey/julia-d386e40c17/bin/julia


mkdir -p output
mkdir -p output/misocp


for SOLVER in BONMIN_OA BONMIN_OADIS BONMIN_BB PAJ_CBC_ECOS PAJ_GLPK_ECOS SCIP_MISOCP CPLEX_MISOCP PAJ_CPLEX_MOSEK PAJ_CPLEX_MOSEK_msd
do
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_A.txt
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_B.txt
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_C.txt
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_D.txt
    $JULIA scripts/runmeta.jl $SOLVER 3600 14000000 cbfs/misocp/ sets/misocp_E.txt
done

mv output/*.txt output/misocp
