#!/bin/bash
set -Ceu

# read experiments.conf, if not present read template

if [ -f experiments.conf ]; then
    source experiments.conf
else
    (>&2 echo "experiments.conf not present, using defaults in templates/experiments.conf.example")
    source templates/experiments.conf.example
fi

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
    assert_folder_structure
    assert_tfcv_negra_files
    assert_tfcv_discodop_files

    for fold in {1..9}; do
        $DISCO runexp "$TMP/grammars/discodop-$fold.prm" &> /dev/null \
            || fail_and_cleanup "results"
        
        tail -n+2 "$TMP/grammars/discodop-$fold/stats.tsv" >> "$TMP/results/discodop-times.txt"
        tail -n+2 "$TMP/grammars/discodop-$fold/plcfrs.export" >> "$TMP/results/discodop-predictions.export"
    done
        
    $DISCO eval "$TMP/negra/test-1-9.export" "$TMP/results/discodop-predictions.export" \
         > "$RESULTS/discodop-tfcv-scores.txt" \
        || fail_and_cleanup "results"
    
    $PYTHON averages.py mean 3 1 < "$TMP/results/discodop-times.txt" > "$RESULTS/discodop-times-mean.csv" \
        || fail_and_cleanup "results"
    $PYTHON averages.py median 3 1 < "$TMP/results/discodop-times.txt" > "$RESULTS/discodop-times-median.csv" \
        || fail_and_cleanup "results"
}

function rustomata_nfcv {
    assert_folder_structure
    assert_tfcv_negra_files
    assert_tfcv_rustomata_files

    for fold in {1..9}; do
        $RUSTOMATA csparsing parse "$TMP/grammars/train-$fold.cs" --beam=$RUSTOMATA_D_BEAM --candidates=$RUSTOMATA_D_CANDIDATES --with-pos --with-lines --debug < "$TMP/negra/test-$fold.sent" \
            2>> "$TMP/results/rustomata-times.csv" \
             >> "$TMP/results/rustomata-predictions.export" \
             || fail_and_cleanup "results"
    done
        
    $DISCO eval "$TMP/negra/test-1-9.export" "$TMP/results/rustomata-predictions.export" \
        >> $RESULTS/rustomata-scores.txt \
        || fail_and_cleanup "results"
    
    $PYTHON averages.py mean 5 1 < "$TMP/results/rustomata-times.csv" >> "$RESULTS/rustomata-times-mean.csv" \
        || fail_and_cleanup "results"
    $PYTHON averages.py median 5 1 < "$TMP/results/rustomata-times.csv" >> "$RESULTS/rustomata-times-median.csv" \
        || fail_and_cleanup "results"
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
    if ! [ -f $TMP/negra/test-1-9.export ]; then
        echo "#FORMAT 3" > $TMP/negra/negra-corpus-low-punctuation.export
        $DISCO treetransforms --punct=move $NEGRA >> $TMP/negra/negra-corpus-low-punctuation.export
        $PYTHON tfcv.py $TMP/negra/negra-corpus-low-punctuation.export --out-prefix=$TMP/negra --max-length=$MAXLENGTH --fix-discodop-transformation=true

        echo "#FORMAT 3" > "$TMP/negra/test-1-9.export"
        for fold in {1..9}; do
            tail -n+2 "$TMP/negra/test-$fold.export" >> "$TMP/negra/test-1-9.export"
        done
    fi
}

function assert_tfcv_rustomata_files {
    if ! (( $# == 1 )); then
        for fold in {0..9}; do
            assert_tfcv_rustomata_files $fold
        done
    else
        if ! [ -f $TMP/grammars/train-$1.cs ]; then
            $VANDA pmcfg extract -p $TMP/grammars/train-$1.vanda < $TMP/negra/train-$1.export || fail_and_cleanup "grammars"
            $RUSTOMATA csparsing extract < $TMP/grammars/train-$1.vanda.readable > $TMP/grammars/train-$1.cs || fail_and_cleanup "grammars"
        fi
    fi
}

function assert_tfcv_discodop_files {
    for fold in {0..9}; do
        if ! [ -d "$TMP/grammars/discodop-train-$fold" ]; then
            sed "s:{TRAIN}:$TMP/negra/train-$fold.export:" templates/discodop.prm \
                | sed "s:{TEST}:$TMP/negra/test-$fold.export:" \
                | sed "s:{MAXLENGTH}:$MAXLENGTH:" \
                | sed "s:{EVALFILE}:$DISCODOP_EVAL:" > "$TMP/grammars/discodop-$fold.prm"
        fi
    done
}

function fail_and_cleanup {
    # if [ -d "$RESULTS" ]; then
    #     $TRASH $RESULTS
    # fi

    # if (( $# == 1 )) && [ -d "$TMP/$1" ]; then
    #     $TRASH "$TMP/$1"
    # fi

    exit 1
}


# main script that runs the procedures for given parameters

if (( $# > 1 )) && [[ "$2" =~ ^--clean ]]; then
    if [ -d "$RESULTS" ]; then $TRASH "$RESULTS"; fi
    if [ -d "$TMP/results" ]; then $TRASH "$TMP/results"; fi
    if [[ "$2" =~ ^--clean-all$ ]]; then
        if [ -d "$TMP/grammars" ]; then $TRASH "$TMP/grammars"; fi
        if [ -d "$TMP/negra" ]; then $TRASH "$TMP/negra"; fi

    fi
fi

if (( $# < 1)) || ! $1; then
    echo "use $0 (((rparse|gf|discodop|rustomata)_nfcv)|rustomata_ofcv) [--clean-[all]]";
fi