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
    assert_folder_structure
    assert_tfcv_negra_files
    assert_tfcv_rparse_files

    for fold in {1..9}; do
        $RPARSE -doParse -test "$TMP/negra/test-$fold.export" -testFormat export -readModel "$TMP/grammars/rparse-train-$fold" -timeout "$RPARSE_TIMEOUT" \
             > >($PYTHON $SCRIPTS/fill_sentence_id.py "$TMP/negra/test-$fold.sent" | $PYTHON $SCRIPTS/fill_noparses.py "$TMP/negra/test-$fold.sent" >> "$TMP/results/rparse-predictions.export")  \
            2> >($PYTHON $SCRIPTS/parse_rparse_output.py >> "$TMP/results/rparse-times.tsv") \
            || fail_and_cleanup "results/rparse-predictions.export" "results/rparse-times.tsv"
    done
        
    $DISCO eval "$TMP/negra/test-1-9.export" "$TMP/results/rparse-predictions.export" \
         > "$RESULTS/rparse-tfcv-scores.txt" \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py mean 1 0 < "$TMP/results/rparse-times.tsv" > "$RESULTS/rparse-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py median 1 0 < "$TMP/results/rparse-times.tsv" > "$RESULTS/rparse-times-median.tsv" \
        || fail_and_cleanup
}

function gf_nfcv {
    assert_folder_structure
    assert_tfcv_negra_files
    assert_tfcv_gf_files

    for fold in {1..1}; do
        gf_with_timeout "$TMP/grammars/gf-$fold/grammargfconcrete.gfo" "$TMP/negra/test-$fold-gf.sent" \
              | $PYTHON $SCRIPTS/parse_gf_output.py "$TMP/negra/test-$fold.sent" \
              > >(sed 's/[[:digit:]]:[[:digit:]]\+//g' | sed 's:$(:_P_OPEN_:g' | $DISCO treetransforms --inputfmt=bracket | sed 's:_P_OPEN_:$(:g' | $PYTHON $SCRIPTS/fill_sentence_id.py "$TMP/negra/test-$fold.sent" >> "$TMP/results/gf-predictions.export") \
            2>> "$TMP/results/gf-times.tsv" \
             || fail_and_cleanup "results/gf-predictions.export" "results/gf-times.tsv"
    done

    $DISCO eval "$TMP/negra/test-1-9.export" "$TMP/results/gf-predictions.export" \
         > "$RESULTS/gf-tfcv-scores.txt" \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py mean 1 0 < "$TMP/results/gf-times.tsv" > "$RESULTS/gf-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py median 1 0 < "$TMP/results/gf-times.tsv" > "$RESULTS/gf-times-median.tsv" \
        || fail_and_cleanup
}

function discodop_nfcv {
    assert_folder_structure
    assert_tfcv_negra_files
    assert_tfcv_discodop_files

    for fold in {1..9}; do
        $DISCO runexp "$TMP/grammars/discodop-$fold.prm" &> /dev/null \
            || fail_and_cleanup "grammars/discodop-$fold"
        
        tail -n+2 "$TMP/grammars/discodop-$fold/stats.tsv" >> "$TMP/results/discodop-times.tsv"
        cat "$TMP/grammars/discodop-$fold/plcfrs.export" >> "$TMP/results/discodop-predictions.export"
    done
        
    $DISCO eval "$TMP/negra/test-1-9.export" "$TMP/results/discodop-predictions.export" \
         > "$RESULTS/discodop-tfcv-scores.txt" \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py mean 3 1 < "$TMP/results/discodop-times.tsv" > "$RESULTS/discodop-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py median 3 1 < "$TMP/results/discodop-times.tsv" > "$RESULTS/discodop-times-median.tsv" \
        || fail_and_cleanup
}

function rustomata_nfcv {
    assert_folder_structure
    assert_tfcv_negra_files
    assert_tfcv_rustomata_files

    for fold in {1..9}; do
        $RUSTOMATA csparsing parse "$TMP/grammars/train-$fold.cs" --beam=$RUSTOMATA_D_BEAM --candidates=$RUSTOMATA_D_CANDIDATES --with-pos --with-lines --debug < "$TMP/negra/test-$fold.sent" \
            2>> "$TMP/results/rustomata-times.tsv" \
              | sed 's:_[[:digit:]]::' >> "$TMP/results/rustomata-predictions.export" \
             || fail_and_cleanup "results/rustomata-times.tsv" "results/rustomata-predictions.export"
    done
        
    $DISCO eval "$TMP/negra/test-1-9.export" "$TMP/results/rustomata-predictions.export" \
        >> $RESULTS/rustomata-scores.txt \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py mean 3 1 < "$TMP/results/rustomata-times.tsv" >> "$RESULTS/rustomata-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py median 3 1 < "$TMP/results/rustomata-times.tsv" >> "$RESULTS/rustomata-times-median.tsv" \
        || fail_and_cleanup
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
                2> "$TMP/results/rustomata-ofcv-$beam-$cans-times.tsv" \
                 | sed 's:_[[:digit:]]::' > "$TMP/results/rustomata-ofcv-$beam-$cans-predictions.export" \
                || fail_and_cleanup "results/rustomata-ofcv-$beam-$cans-times.csv" "results/rustomata-ofcv-$beam-$cans-predictions.export"
            
            echo -ne "$beam\t$cans\t" >> $RESULTS/rustomata-ofcv-scores.tsv
            $DISCO eval $TMP/negra/test-0.export $TMP/results/rustomata-ofcv-$beam-$cans-predictions.export \
                 | grep -oP "labeled (precision|recall|f-measure):\s+\K\d+.\d+" \
                 | awk -vRS="\n" -vORS="\t" '1' >> $RESULTS/rustomata-ofcv-scores.tsv \
                || fail_and_cleanup
            echo "" >> $RESULTS/rustomata-ofcv-scores.tsv
            
            echo -ne "$beam\t$cans\t" >> $RESULTS/rustomata-ofcv-times-mean.tsv
            echo -ne "$beam\t$cans\t" >> $RESULTS/rustomata-ofcv-times-median.tsv
            $PYTHON $SCRIPTS/averages.py mean 3 1 < $TMP/results/rustomata-ofcv-$beam-$cans-times.tsv >> $RESULTS/rustomata-ofcv-times-mean.tsv \
                || fail_and_cleanup
            $PYTHON $SCRIPTS/averages.py median 3 1 < $TMP/results/rustomata-ofcv-$beam-$cans-times.tsv >> $RESULTS/rustomata-ofcv-times-median.tsv \
                || fail_and_cleanup
        done
    done
}

# this section contains helper functions
FOLDERS=("$TMP" "$TMP/grammars" "$TMP/negra" "$TMP/results" "$RESULTS")

# wraps 
function gf_with_timeout {
    outputs=""
    while read sentence || [ -n "$sentence" ]; do
        sentenceoutput="$(echo $sentence | timeout $GF_TIMEOUT $GF $1)"
        ec=$?
        if (( $ec == 124 )); then       # timeout
            outputs="$outputs\nTIMEOUT> (_:0)\n${GF_TIMEOUT}000 msec"
        elif (( $ec != 0 )); then       # some other error
            return $ec
        else                            # no error, propagate output
            lines=$(echo "$sentenceoutput" | grep -P -A1 '^[^>]+> \K.+' | head -n2)
            outputs="$outputs\n$lines"
        fi
    done <"$2"
    echo -e "$outputs"
}

function assert_folder_structure {
    for folder in ${FOLDERS[*]}; do
        if ! [ -d $folder ]; then
            mkdir -p $folder
        fi
    done
}

function assert_tfcv_negra_files {
    if ! [ -f "$TMP/negra/negra-corpus-low-punctuation.export" ]; then
        echo "#FORMAT 3" > $TMP/negra/negra-corpus-low-punctuation.export
        $DISCO treetransforms --punct=move $NEGRA >> $TMP/negra/negra-corpus-low-punctuation.export \
            || fail_and_cleanup "/negra/negra-corpus-low-punctuation.export"
    fi
    if ! [ -f "$TMP/negra/test-1.export" ]; then
        $PYTHON $SCRIPTS/tfcv.py $TMP/negra/negra-corpus-low-punctuation.export --out-prefix=$TMP/negra --max-length=$MAXLENGTH --fix-discodop-transformation=true
    fi
    if ! [ -f "$TMP/negra/test-1-9.export" ]; then
        echo "#FORMAT 3" > "$TMP/negra/test-1-9.export"
        for fold in {1..9}; do
            tail -n+2 "$TMP/negra/test-$fold.export" >> "$TMP/negra/test-1-9.export"
            echo "" >> "$TMP/negra/test-1-9.export"
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
            $VANDA pmcfg extract -p $TMP/grammars/train-$1.vanda < $TMP/negra/train-$1.export || fail_and_cleanup
            $RUSTOMATA csparsing extract < $TMP/grammars/train-$1.vanda.readable > $TMP/grammars/train-$1.cs || fail_and_cleanup "grammars/train-$1.cs"
        fi
    fi
}

function assert_tfcv_discodop_files {
    for fold in {0..9}; do
        if ! [ -f "$TMP/grammars/discodop-$fold.prm" ]; then
            sed "s:{TRAIN}:$TMP/negra/train-$fold.export:" templates/discodop.prm \
                | sed "s:{TEST}:$TMP/negra/test-$fold.export:" \
                | sed "s:{MAXLENGTH}:$MAXLENGTH:" \
                | sed "s:{EVALFILE}:$DISCODOP_EVAL:" > "$TMP/grammars/discodop-$fold.prm"
        fi
    done
}

function assert_tfcv_gf_files {
    for fold in {0..9}; do
        if ! [ -d "$TMP/grammars/gf-$fold" ]; then
            $RPARSE -doTrain -train "$TMP/negra/train-$fold.export" -headFinder negra -trainSave "$TMP/grammars/gf-$fold" &> /dev/null \
                || fail_and_cleanup "grammars/gf-$fold"
            $GF --make "$TMP/grammars/gf-$fold/grammargfconcrete.gf" &> /dev/null \
                || fail_and_cleanup "grammars/gf-$fold"
        fi

        if ! [ -f "$TMP/negra/test-$fold-gf.sent" ]; then
            sed 's/^[[:digit:]]\+[[:space:]]\+//' "$TMP/negra/test-$fold.sent" \
                 | sed 's#/[^[:space:]/]\+[[:space:]]# #g' \
                 | sed 's#/[^[:space:]/]\+$# #g' \
                 | sed --file "$SCRIPTS/gf-escapes.sed" \
                 | sed 's#^.\+$#p -bracket "&"#' > "$TMP/negra/test-$fold-gf.sent" \
                || fail_and_cleanup "negra/test-$fold-gf.sent"
        fi
    done
}

function assert_tfcv_rparse_files {
    for fold in {0..9}; do
        if ! [ -f "$TMP/grammars/rparse-train-$fold" ]; then
            $RPARSE -doTrain -train "$TMP/negra/train-$fold.export" -headFinder negra -saveModel "$TMP/grammars/rparse-train-$fold" &> /dev/null \
                || fail_and_cleanup "grammars/rparse-train-$fold"
        fi
    done
}

function fail_and_cleanup {
    for f in $@; do
        if [ -d "$TMP/$f" ] || [ -f "$TMP/$f" ]; then
            $TRASH "$TMP/$f"
        fi
    done

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