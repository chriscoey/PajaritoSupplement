#!/bin/bash
# run from PajaritoSupplement directory

# print julia path that will be used
echo $(which julia)
echo "should be julia-d386e40c17 (v0.6.2)"

# create folder for output text files
mkdir -p output
mkdir -p output/micp

# run the 5 sets of MICP instances for each of the Pajarito MICP solvers
for SOLVER in PAJ_Gurobi_msd_sep PAJ_Gurobi_sep PAJ_Gurobi_MOSEK_msd PAJ_Gurobi_MOSEK PAJ_Gurobi_MOSEK_msd_noinit PAJ_Gurobi_MOSEK_noinit PAJ_Gurobi_MOSEK_msd_subponly_noinit PAJ_Gurobi_MOSEK_subponly_noinit PAJ_Gurobi_MOSEK_msd_nodisagg_subponly_noinit PAJ_Gurobi_MOSEK_nodisagg_subponly_noinit PAJ_Gurobi_MOSEK_msd_noscale_subponly_noinit PAJ_Gurobi_MOSEK_noscale_subponly_noinit PAJ_Gurobi_MOSEK_msd_scale_subponly_noinit PAJ_Gurobi_MOSEK_scale_subponly_noinit
do
    $JULIA scripts/runmeta.jl --nochecktimemem $SOLVER 3600 40000000 cbfs/micp/ sets/micp_A.txt
    $JULIA scripts/runmeta.jl --nochecktimemem $SOLVER 3600 40000000 cbfs/micp/ sets/micp_B.txt
    $JULIA scripts/runmeta.jl --nochecktimemem $SOLVER 3600 40000000 cbfs/micp/ sets/micp_C.txt
    $JULIA scripts/runmeta.jl --nochecktimemem $SOLVER 3600 40000000 cbfs/misocp/ sets/micp_D.txt
    $JULIA scripts/runmeta.jl --nochecktimemem $SOLVER 3600 40000000 cbfs/misocp/ sets/micp_E.txt
done

# move the outputs to the MICP output folder
mv output/*.txt output/micp
