# MFOTL2RANF

MFOTL2RANF is a tool for translating arbitrary MFOTL queries
to MFOTL queries in RANF (relational algebra normal form)
that can be evaluated using relational algebra operations
on finite tables.
MFOTL queries in RANF can be evaluated by state-of-the-art
MFOTL monitors such as MonPoly, VeriMon, and CppMon.

MFOTL2RANF takes as input a MFOTL query and a training log
and outputs a RANF query.
The RANF query is satisfied by a single tuple
whose variable `__inf` and all free variables of the original MFOTL query
are set to 1 if the original MFOTL query is satisfied by infinitely many tuples
and otherwise the RANF query is satisfied exactly by the tuples satisfying
the original MFOTL query and extended with the variable `__inf` set to 0.

The training log is only used by heuristics in query translation.
The choice of a training log does NOT impact the translation's correctness.

This repository is the supplementary material for Martin Raszyk's PhD thesis.

**Note**: The authors of CppMon are going to make their tool publicly available.
We will extend this repository and the provided Dockerfile once CppMon
becomes available.

---

# Directory Structure:

- `Dockerfile` - Dockerfile for this supplementary material
- `main.tex` - template of a LaTeX document with evaluation results
- `exps_mfotl.sh` - script to run experiments in Section 4.3
- `exps_sinceuntil.sh` - script to run experiments in Section 4.3
- `functions.sh` - helper bash functions
- `examples/` - example queries from this README
- `props/` - queries for empirical evaluation in Section 4.3
- `sinceuntil/` - empirical evaluation in Section 4.4
- `src/` - MFOTL2RANF's source code (in OCaml)
- `tools/` - tool generating queries and logs for our experiments

Further tools:

- `monpoly/` - the *MonPoly* tool and its verified core (*VeriMon*)
- `dejavu/` - the *DejaVu* tool
- `monpoly-reg-1.0/` - the *MonPoly-Reg* tool

---

# Build

We recommend running the experiments using `docker` and the provided `Dockerfile`.
Please set up at least 8 GiB of main memory for your Docker container.
Note that the first command below will take some time to finish.
```
sudo docker build --no-cache -t mfotlranf .
sudo docker run -it mfotlranf
```
Once you run the second command above you will
obtain a shell with all the tools installed.

---

# Usage

To invoke our MFOTL query translation type:

```

$ ./mfotl2ranf ${prefix}

```

where

prefix = prefix of the path to a text file with a MFOTL query (`${prefix}.mfotl`)
and a training log (`${prefix}.tlog`).

MFOTL2RANF outputs a RANF query (`${prefix}.smfotl`) that can be evaluated
by MonPoly, VeriMon, and CppMon.
MFOTL2RANF also output the RANF query in a pretty-printed format (`${prefix}.pmfotl`).

MFOTL Syntax

```
{f} ::=   TRUE
        | FALSE
        | {ID}({s})
        | {ID} = {t}
        | NOT {f}
        | {f} AND {f}
        | {f} OR  {f}
        | EXISTS {ID} . {f}
        | FORALL {ID} . {f}
        | PREV {i} {f}
        | NEXT {i} {f}
        | {f} SINCE {i} {f}
        | {f} UNTIL {i} {f}

{t} ::=   {NUM}
        | {ID}

{s} ::=   %empty
        | {t}
        | {t} , {s}

{i} ::= [ {NUM} , {U} ]
{U} ::= {NUM} | *

```

where `{NUM}` is an integer (constant)
and `{ID}` is an identifier (variable) consisting
of alphanumeric characters.
The symbol `*` represents an infinite upper bound of an interval.
Non-terminals are enclosed in curly braces.

Log Syntax

```
{l} :=    %empty
        | @{TS} {d} {l}

{d} :=    %empty
        | {ID}({s}) {d}

{s} ::=   %empty
        | {NUM}
        | {NUM} , {s}
```

where `{TS}` is a nonnegative integer (time-stamp)
and `{ID}` is an identifier (atomic predicate).

---

# Example

Example showing how to invoke our translation:
```

$ cat examples/ex.mfotl
EXISTS t. EXISTS x. EXISTS l. write(t,x) AND ((NOT (read(t,x) OR rel(t,l))) SINCE acq(t,l))

$ cat examples/ex.tlog
@0 acq(9,9)
@1 read(9,3)
@2 acq(13,19)
@3 acq(15,3)
@4 acq(18,15)
@5 read(13,5)
@6 write(15,4)
@7 write(15,3)
@8 acq(17,13)
@9 write(15,9)
@10 write(13,13)
@11 acq(8,11)
@12 write(18,4)
@13 rel(9,9)
@14 acq(10,10)
@15 read(15,4)
@16 write(15,9)
@17 write(13,10)
@18 acq(7,6)
@19 acq(0,5)

$ ./mfotl2ranf examples/ex

$ cat examples/ex.smfotl
(__inf = 0) AND ((EXISTS t. (EXISTS x. (EXISTS l. (((NOT ((((read(t, x)) AND (ONCE[0, *] (read(t, x)))) AND (ONCE[0, *] (acq(t, l)))) OR (((rel(t, l)) AND (ONCE[0, *] (read(t, x)))) AND (ONCE[0, *] (acq(t, l)))))) SINCE[0, *] (((acq(t, l)) AND (ONCE[0, *] (read(t, x)))) AND (ONCE[0, *] (acq(t, l))))) AND (write(t, x)))))) OR (EXISTS t. (EXISTS x. (EXISTS l. ((((NOT (rel(t, l))) SINCE[0, *] (acq(t, l))) AND (write(t, x))) AND (NOT (ONCE[0, *] (read(t, x)))))))))

$ cat examples/ex.pmfotl
AND
|__inf = 0
|OR
||EXISTS t x l.
|||AND
||||SINCE[0, *]
|||||NOT
||||||OR
|||||||AND
||||||||read(t, x)
||||||||SINCE[0, *]
|||||||||TRUE
|||||||||read(t, x)
||||||||SINCE[0, *]
|||||||||TRUE
|||||||||acq(t, l)
|||||||AND
||||||||rel(t, l)
||||||||SINCE[0, *]
|||||||||TRUE
|||||||||read(t, x)
||||||||SINCE[0, *]
|||||||||TRUE
|||||||||acq(t, l)
|||||AND
||||||acq(t, l)
||||||SINCE[0, *]
|||||||TRUE
|||||||read(t, x)
||||||SINCE[0, *]
|||||||TRUE
|||||||acq(t, l)
||||write(t, x)
||EXISTS t x l.
|||AND
||||SINCE[0, *]
|||||NOT
||||||rel(t, l)
|||||acq(t, l)
||||write(t, x)
||||NOT
|||||SINCE[0, *]
||||||TRUE
||||||read(t, x)

```

---

# Evaluation in Section 4.3

To reproduce the experiments from the thesis, run
```
$ ./exps_mfotl.sh
```

The individual experiments are described in Section 4.3.2.
After the script `exps_mfotl.sh` finishes,
the evaluation times are contained in the files `exps_mfotl_*.tex`
used to plot Tables 4.1, 4.3, ..., 4.7.

A PDF with the translation and evaluation times can be obtained by executing
```
$ pdflatex main.tex
```

The timeout (default: 900s) can be configured
in the first line of the script `exps_mfotl.sh`.

---

# Evaluation in Section 4.4

To reproduce the experiments from the thesis, run
```
$ ./exps_sinceuntil.sh
```

The individual experiments are described in Section 4.4.3.
After the script `exps_sinceuntil.sh` finishes,
the raw data from the experiments are contained in `sinceuntil/stats/`
and the plots are stored in `sinceuntil/figs/`.
The timeout (default: 200s) can be configured in the section `exp_config`
of the configuration file `sinceuntil/config_thesis.py`.

If the time or memory usage does not fit into the predefined
ranges in the plots, you can adjust the ranges by setting
`plot_config_exp[exp_name]["yrange"]["time"]` and
`plot_config_exp[exp_name]["yrange"]["space"]`
(where `exp_name` is, e.g., `exp_sinceuntil_er_since`)
in the configuration file `sinceuntil/config_thesis.py`
and then rerun `python3 proc.py config_thesis.py`
in the directory `sinceuntil/`.

The mapping of the experiment names is summarized here:
- Figure 4.17  -> `exp_sinceuntil_er_*`
- Figure 4.18  -> `exp_sinceuntil_int_*`
