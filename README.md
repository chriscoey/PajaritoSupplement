# PajaritoSupplement

This supplement is for reproducing the computational results in section 6 of "Outer Approximation With Conic Certificates For Mixed-Integer Convex Problems" by Chris Coey, Miles Lubin, and Juan Pablo Vielma.
* Section 6.1 describes our presentation of results in tables and performance profiles.
* Section 6.2 presents the comparisons of 9 MISOCP solvers (3 Bonmin, Pajarito + CBC or GLPK, SCIP, CPLEX, and 2 Pajarito + CPLEX) on our testset of 120 MISOCP (mixed-integer second-order cone programming) instances from CBLIB (http://cblib.zib.de/).
* Section 6.3 presents the comparisons of key algorithmic variants of Pajarito (cut types, cut disaggregation, cut scaling) on our testset of 95 MICP (mixed-integer conic programming) instances (involving mixtures of second-order, exponential, and positive semidefinite cone constraints).

The folders in this supplement are organized as follows.
* `cbfs/` contains our MISOCP and MICP testsets. Each instance file is stored as a gzipped `cbf` file (`.cbf.gz`). CBF is described by Friberg at http://cblib.zib.de/.
* `sets/` contains lists of instances from the `cbfs/` folder. These lists are used by the scripts to test the infrastructure or to run manageable subsets of the instances.
* `scripts/` contains the bash (`.sh`) and Julia (`.jl`) scripts for running the MISOCP and MICP tests on a local machine, processing the raw output from the solvers into `.csv` files ready for further analysis, and generating tables and text files of status counts and geomeans of performance metrics, and generating performance profiles for pairs of solvers.
* `awsscripts/` contains files for running the (time-consuming) MISOCP tests specifically on AWS EC2 cloud compute infrastructure in parallel, rather than on the local machine. This folder is irrelevant if the MISOCP tests are to be run on the local machine.
* `output/` initially contains a text file outputted by the `scripts/run.jl` script for each solver-instance run that we performed. Each text file contains solver logs, errors, warnings, and a printout of the summary information such as objective, solution, status, and execution time. The current set of files should be deleted or moved before running the scripts again.
* `results/` initially contains `.csv` files that are outputted by the `scripts/process_output.jl` script that we ran. Each line in each file corresponds to a solver-instance run, and summarizes the important performance metrics and solution checks. The current set of files should be deleted or moved before running the scripts again.
* `analysis/` initially contains files that are outputted by the `scripts/process_csv.jl` and `xxxx_perf.jl` scripts that we ran. Specifically, a `.txt` file is , a `.tex` file is LaTeX/PGF/TiKZ code that produces a performance profile. The current set of files should be deleted or moved before running the scripts again.


## MISOCP tests (section 6.2)

### Install software

Run all commands from home directory.
```
sudo apt-get update --yes
sudo apt-get -y install build-essential libssl-dev libffi-dev python-dev gfortran pkg-config unzip libgmp-dev libz-dev libreadline-dev libncurses-dev
```
Install Julia v0.6.0.
```
wget https://julialang.s3.amazonaws.com/bin/linux/x64/0.6/julia-0.6.0-linux-x86_64.tar.gz
tar -xvzf julia-0.6.0-linux-x86_64.tar.gz
echo "export PATH=\$PATH:$HOME/julia-903644385b/bin" >> ~/.bashrc
```
Obtain a Mosek licence file `mosek.lic` from Mosek's website. Install Mosek. The wget link may need to be obtained from Mosek directly.
```
wget https://d2i6rjz61faulo.cloudfront.net/alpha/9/mosektoolslinux64x86.tar.bz2
tar -xvjf mosektoolslinux64x86.tar.bz2
mv mosek.lic mosek
```
Install CPLEX to `/home/ubuntu/CPLEX_Studio127`.
```
chmod +x cplex_studio127.linux-x86-64.bin
./cplex_studio127.linux-x86-64.bin
echo "export LD_LIBRARY_PATH=/home/ubuntu/CPLEX_Studio127/cplex/bin/x86-64_linux" >> ~/.bashrc
```
Get Mosek.jl.
```
cd
source .bashrc
julia
Pkg.update()
ENV["MOSEKBINDIR"] = "/home/ubuntu/mosek/9/tools/platform/linux64x86/bin/"
Pkg.clone("https://github.com/chriscoey/Mosek.jl","Mosek")
Pkg.build("Mosek")
exit()
```
Get on chriscoey's special branch of Mosek.jl (with MathProgBase status fixes).
```
cd
cd .julia/v0.6/Mosek
git remote remove origin
git remote add origin https://github.com/chriscoey/Mosek.jl.git
git fetch
git branch --set-upstream-to=origin/master master
git checkout master
git pull
cd
```
Get more Julia packages.
```
julia
Pkg.add("CPLEX")
Pkg.add("JuMP")
Pkg.add("ECOS")
Pkg.add("Cbc")
Pkg.add("Ipopt")
exit()
```
Compile SCIP.
```
echo "export SCIPOPTDIR=/home/ubuntu/scipoptsuite-4.0.0" >> ~/.bashrc
tar xvzf scipoptsuite-4.0.0.tgz
cd scipoptsuite-4.0.0
make SHARED=true GMP=false READLINE=false ZLIB=false OPT=opt IPOPT=true scipoptlib
```
Upon `> Enter soft-link target file or directory for "lib/shared/ipopt.linux.x86_64.gnu.opt" (return if not needed):` input the following.
```
/home/ubuntu/.julia/v0.6/Ipopt/deps/usr
```
Get more Julia packages.
```
cd
julia
Pkg.add("SCIP")
Pkg.add("CoinOptServices")
Pkg.add("AmplNLWriter")
exit()
```
Get v0.3.0 of AmplNLWriter.jl.
```
cd .julia/v0.6/AmplNLWriter
git fetch
git checkout v0.3.0
cd
julia
```
Get more Julia packages.
```
Pkg.add("SCS")
Pkg.add("GLPKMathProgInterface")
Pkg.add("ConicBenchmarkUtilities")
Pkg.add("Pajarito")
Pkg.test("Pajarito")
exit()
```
Tidy up.
```
rm -rf .julia/v0.6/CoinOptServices/deps/src
rm -rf .julia/v0.6/Cbc/deps/src/
rm -rf .julia/v0.6/Ipopt/deps/src/
rm julia-0.6.0-linux-x86_64.tar.gz
rm cplex_studio127.linux-x86-64.bin
rm scipoptsuite-4.0.0.tgz
rm mosektoolslinux64x86.tar.bz2
```
Ensure packages are on correct versions.
```
 - AmplNLWriter                  0.3.0
 - CPLEX                         0.2.8
 - Cbc                           0.3.2
 - CoinOptServices               0.2.0
 - ConicBenchmarkUtilities       0.2.3
 - ECOS                          0.7.2+             master
 - GLPKMathProgInterface         0.3.4
 - Ipopt                         0.2.6
 - JuMP                          0.18.0
 - Mosek                         0.8.2+             master
 - Pajarito                      0.5.0+             master
 - SCIP                          0.4.0
 - Clp                           0.3.1
 - ConicNonlinearBridge          0.1.3
 - GLPK                          0.4.2
 - MathProgBase                  0.6.4
```

Clone supplement repo with data instances and scripts.
```
git clone https://github.com/mlubin/PajaritoSupplement.git
```
Make the bash scripts executable.
```
sudo chmod 777 scripts/run_misocp.sh scripts/run_micp.sh
```

### Run the MISOCP computations

Run the remaining commands from top directory of PajaritoSupplement. If Julia indicates that any packages need to be installed, do so with `Pkg.add("xxxx.jl")`. Ignore any deprecation warnings.

TODO where define JULIA home

Run the bash script.
```
./run_misocp.sh
```

### Process outputs and analyse results

Process raw solver outputs into `.csv' file, then check for inconsistencies.
```
julia scripts/process_output.jl output/misocp results/misocp.csv
julia scripts/process_csv.jl check results/misocp.csv
```
If there are solver-instance runs to exclude, list them in an "exclude" file `scripts/misocp_exclude.txt`, after clearing the file of any solver-instance runs that we listed.

Generate table with status counts, and text file with geomeans and solved instances.
```
julia scripts/process_csv.jl statuscounts results/misocp.csv analysis/misocp_statuscounts.csv --exclude=scripts/misocp_exclude.txt
julia scripts/process_csv.jl geomeans results/misocp.csv --exclude=scripts/misocp_exclude.txt > analysis/misocp_geomeans.txt
```
Generate performance profiles.
```
julia scripts/process_csv.jl perfprofile results/misocp.csv analysis/misocp_perf.jld BONMIN PAJ_CBC_ECOS PAJ_GLPK_ECOS SCIP_MISOCP CPLEX_MISOCP PAJ_CPLEX_MOSEK PAJ_CPLEX_MOSEK_msd --exclude=scripts/misocp_exclude.txt --bestof="BONMIN BONMIN_BB BONMIN_OA BONMIN_OADIS"
julia scripts/misocp_perf.jl analysis
```

## MICP tests (section 6.3)

### Install software

This must be performed after the software installation steps for the MISOCP tests above.
TODO have to get julia v0.6.2 now, update some packages

Install Julia v0.6.2.
```
wget https://julialang.s3.amazonaws.com/bin/linux/x64/0.6/julia-0.6.2-linux-x86_64.tar.gz
tar -xvzf julia-0.6.2-linux-x86_64.tar.gz
echo "export PATH=\$PATH:$HOME/julia-d386e40c17/bin" >> ~/.bashrc
```
Install Gurobi 7.5.2. Install Gurobi.jl following instructions at https://github.com/JuliaOpt/Gurobi.jl.
```
julia
Pkg.add("Gurobi")
exit()
```
Update packages to correct versions.
- ConicBenchmarkUtilities       0.2.3+             master
- Gurobi                        0.3.3
- JuMP                          0.18.0
- Mosek                         0.8.2+             master
- Pajarito                      0.5.0+             master
- MathProgBase                  0.7.0


### Run the MICP computations

Run the remaining commands from top directory of PajaritoSupplement. If Julia indicates that any packages need to be installed, do so with `Pkg.add("xxxx.jl")`. Ignore any deprecation warnings.

TODO where define JULIA home

Run the bash script.
```
./run_micp.sh
```

### Exclude problematic solver-instance runs

Process raw solver outputs into `.csv' file, then check for inconsistencies.
```
julia scripts/process_output.jl output/scale output/cuttypes output/disagg results/micp.csv
julia scripts/process_csv.jl check results/micp.csv
```
If there are solver-instance runs to exclude, list them in "exclude" files below, after clearing the files of any solver-instance runs that we listed.
* `scripts/scale_exclude.txt` for noscale/scale solvers.
* `scripts/disagg_exclude.txt` for disagg/nodisagg solvers.
* `scripts/cuttypes_exclude.txt` for other solvers.

### Cut types (section 6.3.1)

Process raw solver outputs into `.csv' file.
```
julia scripts/process_output.jl output/cuttypes results/cuttypes.csv
```
Generate table with status counts.
```
julia scripts/process_csv.jl statuscounts results/cuttypes.csv analysis/cuttypes_statuscounts.csv --exclude=scripts/cuttypes_exclude.txt
julia scripts/process_csv.jl geomeans results/cuttypes.csv --exclude=scripts/cuttypes_exclude.txt > analysis/cuttypes_geomeans.txt
```
Generate performance profiles.
```
julia scripts/process_csv.jl perfprofile results/cuttypes.csv analysis/cuttypes_perf.jld PAJ_Gurobi_MOSEK PAJ_Gurobi_MOSEK_msd PAJ_Gurobi_sep PAJ_Gurobi_msd_sep --exclude=scripts/cuttypes_exclude.txt
julia scripts/cuttypes_perf.jl analysis
```

### Cut disaggregation (section 6.3.2)

Process raw solver outputs into `.csv' file.
```
julia scripts/process_output.jl output/disagg results/disagg.csv
```
Generate table with status counts, and text file with geomeans and solved instances.
```
julia scripts/process_csv.jl statuscounts results/disagg.csv analysis/disagg_statuscounts.csv --exclude=scripts/disagg_exclude.txt
julia scripts/process_csv.jl geomeans results/disagg.csv --exclude=scripts/disagg_exclude.txt > analysis/disagg_geomeans.txt
```
Generate performance profiles.
```
julia scripts/process_csv.jl perfprofile results/disagg.csv analysis/disagg_perf.jld PAJ_Gurobi_MOSEK_nodisagg_subponly_noinit PAJ_Gurobi_MOSEK_msd_nodisagg_subponly_noinit PAJ_Gurobi_MOSEK_subponly_noinit PAJ_Gurobi_MOSEK_msd_subponly_noinit --exclude=scripts/disagg_exclude.txt
julia scripts/disagg_perf.jl analysis
```

### Cut scaling (section 6.3.3)

Process raw solver outputs into `.csv' file.
```
julia scripts/process_output.jl output/scale results/scale.csv
```
Generate table with status counts, and text file with geomeans and solved instances.
```
julia scripts/process_csv.jl statuscounts results/scale.csv analysis/scale_statuscounts.csv --exclude=scripts/scale_exclude.txt
julia scripts/process_csv.jl geomeans results/scale.csv --exclude=scripts/scale_exclude.txt > analysis/scale_geomeans.txt
```
Generate performance profiles.
```
julia scripts/process_csv.jl perfprofile results/scale.csv analysis/scale_perf.jld PAJ_Gurobi_MOSEK_noscale_subponly_noinit PAJ_Gurobi_MOSEK_msd_noscale_subponly_noinit PAJ_Gurobi_MOSEK_scale_subponly_noinit PAJ_Gurobi_MOSEK_msd_scale_subponly_noinit  --exclude=scripts/scale_exclude.txt
julia scripts/scale_perf.jl analysis
```
