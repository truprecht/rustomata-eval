#!/bin/bash
set -Ceux

# max sentence length
MAXLENGTH=1

# paths
TMP="/tmp/rustomata-cs"
RESULTS="results"
NEGRA="../negra/negra-corpus.utf"

# tools
RUSTOMATA="$HOME/rustomata/target/release/rustomata"
VANDA="$HOME/.local/bin/vanda"
RPARSE="java -jar rparse/rparse.jar"
GF="gf/.cabal-sandbox/bin/gf"
DISCO="discodop"
PYTHON="python"

# approximation parameters
RUSTOMATA_D_CANDIDATES="100"
RUSTOMATA_D_BEAM="10000"
RUSTOMATA_BEAMS=("100" "1000" "10000" "100000")
RUSTOMATA_CANDIDATES=("1" "10" "100" "1000")
RPARSE_TIMEOUT="30"


# this section contains the top-level experiment functions for each parser,
# they will create tsv files for the parse time of each sentence in 
# <RESULTS>/<parser>-time.tsv and discodop's output for the accuracy in
# <RESULTS>/<parser>-scores.txt 

function rparse_nfcv {
    echo "warning: not implemented"
}

function gf_nfcv {
    echo "warning: not implemented"
}

function discodop_nfcv {
    echo "warning: not implemented"
}

function rustomata_nfcv {
    echo "warning: not implemented"
}

# this section contains the function to evaluate the meta-parameters for
# rustomata, the results are stored in <RESULTS>/rustomata-ofcv-scores.txt and
# <RESULTS>/rustomata-ofcv-times-(mean|median).csv

function rustomata_ofcv {
    assert_folder_structure
    assert_tfcv_negra_files
    assert_tfcv_rustomata_files 0

    for beam in ${RUSTOMATA_BEAMS[*]}; do
        for cans in ${RUSTOMATA_CANDIDATES[*]}; do
            $RUSTOMATA csparsing parse $TMP/grammars/train-0.cs --beam=$beam --candidates=$cans --with-pos --with-lines --debug < $TMP/negra/test-0.sent \
                2> $TMP/results/rustomata-ofcv-$beam-$cans-times.csv \
                 > $TMP/results/rustomata-ofcv-$beam-$cans-predictions.export \
                || fail_and_cleanup "results"
            
            echo -ne "$beam\t$cans\t" >> $RESULTS/rustomata-ofcv-scores.txt
            $DISCO eval $TMP/negra/test-0.export $TMP/results/rustomata-ofcv-$beam-$cans-predictions.export \
                 | grep -oP "labeled (precision|recall|f-measure):\s+\K\d+.\d+" \
                 | awk -vRS="\n" -vORS="\t" '1' >> $RESULTS/rustomata-ofcv-scores.txt \
                || fail_and_cleanup "results"
            echo "" >> $RESULTS/rustomata-ofcv-scores.txt
            
            echo -ne "$beam\t$cans\t" >> $RESULTS/rustomata-ofcv-times-mean.csv
            echo -ne "$beam\t$cans\t" >> $RESULTS/rustomata-ofcv-times-median.csv
            $PYTHON averages.py mean 5 1 < $TMP/results/rustomata-ofcv-$beam-$cans-times.csv >> $RESULTS/rustomata-ofcv-times-mean.csv \
                || fail_and_cleanup "results"
            $PYTHON averages.py median 5 1 < $TMP/results/rustomata-ofcv-$beam-$cans-times.csv >> $RESULTS/rustomata-ofcv-times-median.csv \
                || fail_and_cleanup "results"
        done
    done
}

# this section contains helper functions
FOLDERS=("$TMP" "$TMP/grammars" "$TMP/negra" "$TMP/results" "$RESULTS")

function assert_folder_structure {
    for folder in ${FOLDERS[*]}; do
        if ! [ -d $folder ]; then
            mkdir -p $folder
        fi
    done
}

function assert_tfcv_negra_files {
    if ! [ -f $TMP/negra/train-0.export ]; then
        echo "#FORMAT 3" > $TMP/negra/negra-corpus-low-punctuation.export
        $DISCO treetransforms --punct=move $NEGRA >> $TMP/negra/negra-corpus-low-punctuation.export
        $PYTHON tfcv.py $TMP/negra/negra-corpus-low-punctuation.export --out-prefix=$TMP/negra --max-length=$MAXLENGTH --fix-discodop-transformation=true
    fi
}

function assert_tfcv_rustomata_files {
    if [ -z $1 ]; then
        for fold in {0 .. 10}; do
            assert_assert_rustomata_files $fold
        done
    else
        if ! [ -f $TMP/grammars/train-$1.cs ]; then
            $VANDA pmcfg extract -p $TMP/grammars/train-$1.vanda < $TMP/negra/train-$1.export || fail_and_cleanup "grammars"
            $RUSTOMATA csparsing extract < $TMP/grammars/train-$1.vanda.readable > $TMP/grammars/train-$1.cs || fail_and_cleanup "grammars"
        fi
    fi
}

function fail_and_cleanup {
    if [ -d "$RESULTS" ]; then
        rm -r $RESULTS
    fi

    if ! [ -z "$1" ] && [ -d "$TMP/$1" ]; then
        rm -r "$TMP/$1"
    fi

    exit 1
}

# main script that runs the procedures for given parameters

if [ -z $1 ] || ! $1; then
    echo "use $0 (((rparse|gf|discodop|rustomata)_nfcv)|rustomata_ofcv)";
fi