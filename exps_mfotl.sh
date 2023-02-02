to=900

ulimit -s 1048576

. "./functions.sh"

prefix="/home/mfotlranf"

function gen-ours() {
  local from="${1}"
  local to="${2}"
  local n="${3}"

  for i in `seq ${from} ${to}`
  do
    ./tools/races z_${i} "${n}" "${n}" "${n}" "${n}" 0
    n="$((2 * (${n})))"
  done

  seeds=`seq ${from} ${to}`
}

function gen-havelund() {
  local from="${1}"

  cp /home/mfotlranf/dejavu/src/test/scala/tests_fmsd/property6-locks-datarace/10,000/log-monpoly.txt z_$((${from})).log
  cp /home/mfotlranf/dejavu/src/test/scala/tests_fmsd/property6-locks-datarace/10,000/log-dejavu.txt z_$((${from})).csv
  echo "6" > z_$((${from})).bits
  cp /home/mfotlranf/dejavu/src/test/scala/tests_fmsd/property6-locks-datarace/100,000/log-monpoly.txt z_$((${from} + 1)).log
  cp /home/mfotlranf/dejavu/src/test/scala/tests_fmsd/property6-locks-datarace/100,000/log-dejavu.txt z_$((${from} + 1)).csv
  echo "10" > z_$((${from} + 1)).bits
  cp /home/mfotlranf/dejavu/src/test/scala/tests_fmsd/property6-locks-datarace/1,000,000/log-monpoly.txt z_$((${from} + 2)).log
  cp /home/mfotlranf/dejavu/src/test/scala/tests_fmsd/property6-locks-datarace/1,000,000/log-dejavu.txt z_$((${from} + 2)).csv
  echo "9" > z_$((${from} + 2)).bits

  seeds=`seq ${from} $((${from} + 2))`
}

function gen-unbounded() {
  local name="${1}"
  local from="${2}"
  local to="${3}"

  for i in `seq ${from} ${to}`
  do
    cp props/${name}.smfotl z_${i}.smfotl
    cp props/${name}.mrfotl z_${i}.mrfotl
    cp props/${name}.qtl z_${i}.qtl
    cp props/${name}.permqtl z_${i}.permqtl
    cp props/datarace.sig z_${i}.sig
  done
}

function gen-bounded() {
  local name="${1}"
  local from="${2}"
  local to="${3}"
  local n="${4}"
  local sub="${5}"

  for i in `seq ${from} ${to}`
  do
    k1="$(((${n}) / 10))"
    k2="$(((${k1}) - (${sub})))"
    sed "s/100/${k1}/g" props/${name}.mfotl > z_${i}.mfotl
    sed "s/100/${k1}/g" props/${name}.mrfotl > z_${i}.mrfotl
    if [[ -f "props/${name}.qtl" ]]
    then
      sed "s/100/${k2}/g" props/${name}.qtl > z_${i}.qtl
      sed "s/100/${k2}/g" props/${name}.permqtl > z_${i}.permqtl
    fi
    cp props/datarace.sig z_${i}.sig
    cp props/datarace.tlog z_${i}.tlog
    ./mfotl2ranf z_${i}
    n="$((2 * (${n})))"
  done
}

function ours() {
  # lineskip "\\vmon" run01A "ratios"
  # lineskip "\\monpoly" run01B "ratios"
  lineskip "staticmon" run01C "ratios"
}

function alltools() {
  ours
  # lineskip "\\dejavu" run02A "ratios"
  # lineskip "\\dejavuperm" run02B "ratios"
}

function transltime() {
  echo -n "\\sracesint{[0,\\infty]}&"
  runNoTO "./mfotl2ranf props/datarace-havelund-manual"
  echo "\\\\"
  echo -n "\\racesint{[0,\\infty]}&"
  runNoTO "./mfotl2ranf props/datarace-havelund"
  echo "\\\\"
  echo -n "\\sracesintsharp{[0,\\infty]}&"
  runNoTO "./mfotl2ranf props/datarace-unbounded-manual"
  echo "\\\\"
  echo -n "\\racesintsharp{[0,\\infty]}&"
  runNoTO "./mfotl2ranf props/datarace-unbounded"
  echo "\\\\"
  echo -n "\\racesintsharp{[0,\\tracelength/10]}&"
  runNoTO "./mfotl2ranf props/datarace-upper"
  echo "\\\\"
  echo -n "\\pastlockint{[0,\\infty]}&"
  runNoTO "./mfotl2ranf props/past-unbounded"
  echo "\\\\"
  echo -n "\\pastlockint{[0,\\tracelength/10]}&"
  runNoTO "./mfotl2ranf props/past-upper"
  echo "\\\\"
  echo -n "\\pastlockint{[\\tracelength/10,\\infty]}&"
  runNoTO "./mfotl2ranf props/past-lower"
  echo "\\\\"
  echo -n "\\futurelockint{[0,\\tracelength/10]}&"
  runNoTO "./mfotl2ranf props/future-upper"
  echo "\\\\"
}

function static-compile() {

for fma in $(ls z_*.smfotl); do

  base=$(echo $fma | cut -d "." -f1)

  monpoly-staticmon -sig $base.sig -formula $fma -explicitmon -explicitmon_prefix=./staticmon/src/staticmon/input_formula

  cd staticmon
  ninja -C builddir > /dev/null 2> /dev/null
  cp ./builddir/bin/staticmon ./$base
  cd ..

done

for log in $(ls z_*.log); do

  base=$(echo $log | cut -d "." -f1)
  cat $log | sed 's/.*/&\;/g' > "$base.xlog"

done 

}

transltime > exps_mfotl_00.tex

gen-havelund 0
gen-unbounded "datarace-havelund-manual" 0 2
static-compile
echo "&\\multicolumn{3}{c}{\\sracesint{[0,\\infty]}}\\\\" > exps_mfotl_01.tex
alltools >> exps_mfotl_01.tex
gen-unbounded "datarace-havelund" 0 2
static-compile
echo "\\hline" >> exps_mfotl_01.tex
echo "&\\multicolumn{3}{c}{\\racesint{[0,\\infty]}}\\\\" >> exps_mfotl_01.tex
lineskip "\\dejavu" run02A "ratios" >> exps_mfotl_01.tex
lineskip "\\dejavuperm" run02B "ratios" >> exps_mfotl_01.tex

gen-ours 0 6 250
gen-unbounded "datarace-havelund-manual" 0 6
static-compile
echo "&\\multicolumn{7}{c}{\\sracesint{[0,\\infty]}}\\\\" > exps_mfotl_02.tex
alltools >> exps_mfotl_02.tex
gen-unbounded "datarace-havelund" 0 6
static-compile
echo "\\hline" >> exps_mfotl_02.tex
echo "&\\multicolumn{7}{c}{\\racesint{[0,\\infty]}}\\\\" >> exps_mfotl_02.tex
alltools >> exps_mfotl_02.tex

gen-ours 0 6 250
gen-unbounded "datarace-unbounded-manual" 0 6
static-compile
echo "&\\multicolumn{7}{c}{\\sracesintsharp{[0,\\infty]}}\\\\" > exps_mfotl_03.tex
alltools >> exps_mfotl_03.tex
gen-unbounded "datarace-unbounded" 0 6
static-compile
echo "\\hline" >> exps_mfotl_03.tex
echo "&\\multicolumn{7}{c}{\\racesintsharp{[0,\\infty]}}\\\\" >> exps_mfotl_03.tex
alltools >> exps_mfotl_03.tex

gen-ours 0 5 250
gen-bounded "datarace-upper" 0 5 250 0
static-compile
alltools > exps_mfotl_04.tex

gen-ours 0 3 4000
gen-unbounded "past-unbounded" 0 3
static-compile
alltools > exps_mfotl_05.tex

gen-ours 0 6 250
gen-bounded "past-upper" 0 6 250 0
static-compile
echo "&\\multicolumn{7}{c}{\\pastlockint{[0,\\tracelength/10]}}\\\\" > exps_mfotl_06.tex
alltools >> exps_mfotl_06.tex
gen-bounded "past-lower" 0 6 250 1
static-compile
echo "\\hline" >> exps_mfotl_06.tex
echo "&\\multicolumn{7}{c}{\\pastlockint{[\\tracelength/10,\\infty]}}\\\\" >> exps_mfotl_06.tex
alltools >> exps_mfotl_06.tex

gen-ours 0 3 4000
gen-bounded "future-upper" 0 3 4000 0
static-compile
ours > exps_mfotl_07.tex
lineskip "\\mpreg" run03 "ratios" >> exps_mfotl_07.tex
