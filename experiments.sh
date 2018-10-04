#!/bin/bash
set -Ceu

# read experiments.conf, if not present read template

source templates/experiments.conf.example
if [ -f experiments.conf ]; then
    source experiments.conf
else
    (>&2 echo "experiments.conf not present, using defaults in templates/experiments.conf.example")
fi

# this section contains the top-level experiment functions for each parser,
# they will create tsv files for the parse time of each sentence in 
# <RESULTS>/<parser>-time.tsv and discodop's output for the accuracy in
# <RESULTS>/<parser>-scores.txt 

function _rparse_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_rparse_files "$corpus"

    echo -e "len\ttime\tsuccess" >> "$TMP/$corpus/results/rparse-times.tsv"
    for fold in {1..9}; do
        $RPARSE -doParse -test "$TMP/$corpus/splits/test-$fold.export" -testFormat export -readModel "$TMP/$corpus/grammars/rparse-train-$fold" -timeout "$RPARSE_TIMEOUT" \
             > >($PYTHON $SCRIPTS/fill_sentence_id.py "$TMP/$corpus/splits/test-$fold.sent" | $PYTHON $SCRIPTS/fill_noparses.py "$TMP/$corpus/splits/test-$fold.sent" >> "$TMP/$corpus/results/rparse-predictions.export")  \
            2> >($PYTHON $SCRIPTS/parse_rparse_output.py >> "$TMP/$corpus/results/rparse-times.tsv") \
            || fail_and_cleanup "$corpus/results/rparse-predictions.export" "$corpus/results/rparse-times.tsv"
    done
        
    $DISCO eval "$TMP/$corpus/splits/test-1-9.export" "$TMP/$corpus/results/rparse-predictions.export" \
         > "$RESULTS/rparse-$corpus-scores.txt" \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py --group=len --mean=time < "$TMP/$corpus/results/rparse-times.tsv" > "$RESULTS/rparse-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=time < "$TMP/$corpus/results/rparse-times.tsv" > "$RESULTS/rparse-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

function _gf_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_gf_files "$corpus"

    echo -e "len\ttime\tsuccess" >> "$TMP/$corpus/results/gf-times.tsv"
    for fold in {1..9}; do
        gf_with_timeout "$TMP/$corpus/grammars/gf-$fold/grammargfconcrete.gfo" "$TMP/$corpus/splits/test-$fold-gf.sent" \
              | $PYTHON $SCRIPTS/parse_gf_output.py "$TMP/$corpus/splits/test-$fold.sent" \
              > >($DISCO treetransforms --inputfmt=bracket | $PYTHON $SCRIPTS/gf-escapes-rev.py | $PYTHON $SCRIPTS/fill_sentence_id.py "$TMP/$corpus/splits/test-$fold.sent" >> "$TMP/$corpus/results/gf-predictions.export") \
            2>> "$TMP/$corpus/results/gf-times.tsv" \
             || fail_and_cleanup "results/gf-predictions.export" "results/gf-times.tsv"
    done

    $DISCO eval "$TMP/$corpus/splits/test-1-9.export" "$TMP/$corpus/results/gf-predictions.export" \
         > "$RESULTS/gf-$corpus-scores.txt" \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py --group=len --mean=time < "$TMP/$corpus/results/gf-times.tsv" > "$RESULTS/gf-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=time < "$TMP/$corpus/results/gf-times.tsv" > "$RESULTS/gf-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

function _discolcfrs_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_discodop_files "$corpus"

    echo -e "sentid\tlen\tstage\telapsedtime\tlogprob\tfrags\tnumitems\tgolditems\ttotalgolditems" > "$TMP/$corpus/results/discodop-times.tsv"
    for fold in {1..9}; do
        $DISCO runexp "$TMP/$corpus/grammars/discodop-$fold.prm" \
            || fail_and_cleanup "grammars/discodop-$fold"
        
        tail -n+2 "$TMP/$corpus/grammars/discodop-$fold/stats.tsv" >> "$TMP/$corpus/results/discodop-times.tsv"
        cat "$TMP/$corpus/grammars/discodop-$fold/plcfrs.export" >> "$TMP/$corpus/results/discodop-predictions.export"
    done
        
    $DISCO eval "$TMP/$corpus/negra/test-1-9.export" "$TMP/$corpus/results/discodop-predictions.export" \
         > "$RESULTS/discodop-tfcv-scores.txt" \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py --group=len --mean=elapsedtime < "$TMP/$corpus/results/discodop-times.tsv" > "$RESULTS/discodop-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=elapsedtime  < "$TMP/$corpus/results/discodop-times.tsv" > "$RESULTS/discodop-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

function _discodop_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_discodop_files "$corpus"

    echo -e "sentid\tlen\telapsedtime" > "$TMP/$corpus/results/discodop-dop-times.tsv"
    for fold in {1..9}; do
        $DISCO runexp "$TMP/$corpus/grammars/discodop-$fold-dop.prm" &> /dev/null \
            || fail_and_cleanup "grammars/discodop-$fold-dop"
        
        $PYTHON $SCRIPTS/averages.py --group=sentid --mean=len --sum=elapsedtime < "$TMP/$corpus/grammars/discodop-$fold-dop/stats.tsv" \
            | tail -n+2 >> "$TMP/$corpus/results/discodop-dop-times.tsv"
        cat "$TMP/$corpus/grammars/discodop-$fold-dop/dop.export" >> "$TMP/$corpus/results/discodop-dop-predictions.export"
    done
        
    $DISCO eval "$TMP/$corpus/negra/test-1-9.export" "$TMP/$corpus/results/discodop-dop-predictions.export" \
         > "$RESULTS/discodop-dop-tfcv-scores.txt" \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py --group=len --mean=elapsedtime < "$TMP/$corpus/results/discodop-dop-times.tsv" > "$RESULTS/discodop-dop-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=elapsedtime < "$TMP/$corpus/results/discodop-dop-times.tsv" > "$RESULTS/discodop-dop-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

function _rustomata_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_rustomata_files "$corpus"

    echo -e "grammarsize\tlen\tgrammarsize_after_filtering\ttime\tresult\tcandidates" >> "$TMP/$corpus/results/rustomata-times.tsv"
    for fold in {1..9}; do
        $RUSTOMATA csparsing parse "$TMP/$corpus/grammars/train-$fold.cs" --beam=$RUSTOMATA_D_BEAM --candidates=$RUSTOMATA_D_CANDIDATES --with-pos --with-lines --debug < "$TMP/$corpus/splits/test-$fold.sent" \
            2> >(sed 's: :\t:g' >> "$TMP/$corpus/results/rustomata-times.tsv") \
             | sed 's:_[[:digit:]]::' >> "$TMP/$corpus/results/rustomata-predictions.export" \
            || fail_and_cleanup "results/rustomata-times.tsv" "results/rustomata-predictions.export"
    done
        
    $DISCO eval "$TMP/$corpus/splits/test-1-9.export" "$TMP/$corpus/results/rustomata-predictions.export" \
        >> $RESULTS/rustomata-scores.txt \
        || fail_and_cleanup
    
    $PYTHON $SCRIPTS/averages.py --group=len --mean=time < "$TMP/$corpus/results/rustomata-times.tsv" >> "$RESULTS/rustomata-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=time < "$TMP/$corpus/results/rustomata-times.tsv" >> "$RESULTS/rustomata-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

# this section contains the function to evaluate the meta-parameters for
# rustomata, the results are stored in <RESULTS>/rustomata-ofcv-scores.txt and
# <RESULTS>/rustomata-ofcv-times-(mean|median).csv

function _rustomata_dev_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_rustomata_files "$corpus" 0

    echo -e "beam\tcandidates\tlen\ttime" > $RESULTS/rustomata-ofcv-$corpus-times-mean.tsv 
    echo -e "beam\tcandidates\tlen\ttime" > $RESULTS/rustomata-ofcv-$corpus-times-median.tsv 
    for beam in ${RUSTOMATA_BEAMS[*]}; do
        for cans in ${RUSTOMATA_CANDIDATES[*]}; do
            echo -e "grammarsize\tlen\tgrammarsize_after_filtering\ttime\tresult\tcandidates" > "$TMP/$corpus/results/rustomata-ofcv-$beam-$cans-times.tsv"
            $RUSTOMATA csparsing parse $TMP/$corpus/grammars/train-0.cs --beam=$beam --candidates=$cans --with-pos --with-lines --debug < $TMP/$corpus/splits/test-0.sent \
                2> >(sed 's: :\t:g' >> "$TMP/$corpus/results/rustomata-ofcv-$beam-$cans-times.tsv") \
                 | sed 's:_[[:digit:]]::' > "$TMP/$corpus/results/rustomata-ofcv-$beam-$cans-predictions.export" \
                || fail_and_cleanup "results/rustomata-ofcv-$beam-$cans-times.csv" "results/rustomata-ofcv-$beam-$cans-predictions.export"
            
            echo -ne "$beam\t$cans\t" >> $RESULTS/rustomata-ofcv-$corpus-scores.tsv
            $DISCO eval $TMP/$corpus/splits/test-0.export $TMP/$corpus/results/rustomata-ofcv-$beam-$cans-predictions.export \
                 | grep -oP "labeled (precision|recall|f-measure):\s+\K\d+.\d+" \
                 | awk -vRS="\n" -vORS="\t" '1' >> $RESULTS/rustomata-ofcv-$corpus-scores.tsv \
                || fail_and_cleanup
            echo "" >> $RESULTS/rustomata-ofcv-$corpus-scores.tsv
            
            $PYTHON $SCRIPTS/averages.py --group=len --mean=time < $TMP/$corpus/results/rustomata-ofcv-$beam-$cans-times.tsv \
                 | tail -n+2 | head -n-2 \
                 | sed "s:^:$beam\t$cans\t:" >> $RESULTS/rustomata-ofcv-$corpus-times-mean.tsv \
                || fail_and_cleanup
            $PYTHON $SCRIPTS/averages.py --group=len --median=time < $TMP/$corpus/results/rustomata-ofcv-$beam-$cans-times.tsv \
                 | tail -n+2 | head -n-2 \
                 | sed "s:^:$beam\t$cans\t:" >> $RESULTS/rustomata-ofcv-$corpus-times-median.tsv \
                || fail_and_cleanup
        done
    done
}

# wraps `timeout` around gf
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


#
function assert_folder_structure {
    if ! [ -d "$TMP/$1/splits" ]; then mkdir -p "$TMP/$1/splits"; fi
    if ! [ -d "$TMP/$1/grammars" ]; then mkdir "$TMP/$1/grammars"; fi
    if ! [ -d "$TMP/$1/results" ]; then mkdir "$TMP/$1/results"; fi

    if ! [ -d "$RESULTS" ]; then mkdir -p "$RESULTS"; fi
}

# IN:
# - PARAMETERS: $1 – corpus, $2 – corpus name
# - FILES: $1
# OUT:
# - FILES: $TMP/$2/splits/(train|test)-(0|…|9).(export|sent)
function assert_corpus_files {
    if (( $# != 2 )) || ! [ -d "$TMP/$2" ]; then return 1; fi

    if ! [ -f "$TMP/$2/low-punctuation.export" ]; then
        echo "#FORMAT 3" > "$TMP/$2/low-punctuation.export"
        $DISCO treetransforms --punct=move "$1" >> "$TMP/$2/low-punctuation.export" \
            || fail_and_cleanup "$2/low-punctuation.export"
    fi
    if ! [ -f "$TMP/$2/splits/test-0.export" ]; then
        $PYTHON $SCRIPTS/tfcv.py "$TMP/$2/low-punctuation.export" --out-prefix="$TMP/$2/splits" --max-length=$MAXLENGTH --fix-discodop-transformation=true
    fi
    if ! [ -f "$TMP/$2/splits/test-1-9.export" ]; then
        echo "#FORMAT 3" > "$TMP/$2/splits/test-1-9.export"
        for fold in {1..9}; do
            tail -n+2 "$TMP/$2/splits/test-$fold.export" >> "$TMP/$2/splits/test-1-9.export"
            echo "" >> "$TMP/$2/splits/test-1-9.export"
        done
    fi
}

# IN:
# - PARAMETERS: $1 – corpus name, $2 – fold number (optional)
# - FILES: $TMP/$1/splits/train-(0|…|9).export or $TMP/$1/splits/train-$2.export (if $2 is given)
# OUT:
# - FILES: $TMP/$1/grammars/train-(0|…|9).(vanda[.readable]|.cs) or $TMP/$1/grammars/train-$2.(vanda[.readable]|.cs)
function assert_tfcv_rustomata_files {
    if (( $# == 1 )); then
        for fold in {0..9}; do
            assert_tfcv_rustomata_files "$1" "$fold"
        done
    else
        if ! [ -f "$TMP/$1/grammars/train-$2.cs" ]; then
            $VANDA pmcfg extract -p "$TMP/$1/grammars/train-$2.vanda" < "$TMP/$1/splits/train-$2.export" || fail_and_cleanup
            $RUSTOMATA csparsing extract < "$TMP/$1/grammars/train-$2.vanda.readable" > "$TMP/$1/grammars/train-$2.cs" || fail_and_cleanup "$1/grammars/train-$2.cs"
        fi
    fi
}

function assert_tfcv_discodop_files {
    for fold in {0..9}; do
        if ! [ -f "$TMP/$1/grammars/discodop-$fold.prm" ]; then
            sed "s:{TRAIN}:$TMP/$1/splits/train-$fold.export:" templates/discodop.prm \
                | sed "s:{TEST}:$TMP/$1/splits/test-$fold.export:" \
                | sed "s:{MAXLENGTH}:$MAXLENGTH:" \
                | sed "s:{EVALFILE}:$DISCODOP_EVAL:" > "$TMP/$1/grammars/discodop-$fold.prm"
        fi
        if ! [ -f "$TMP/$1/grammars/discodop-$fold-dop.prm" ]; then
            sed "s:{TRAIN}:$TMP/$1/splits/train-$fold.export:" templates/discodop-dop.prm \
                | sed "s:{TEST}:$TMP/$1/splits/test-$fold.export:" \
                | sed "s:{MAXLENGTH}:$MAXLENGTH:" \
                | sed "s:{EVALFILE}:$DISCODOP_EVAL:" > "$TMP/$1/grammars/discodop-$fold-dop.prm"
        fi
    done
}

function assert_tfcv_gf_files {
    for fold in {0..9}; do
        if ! [ -d "$TMP/$1/grammars/gf-$fold" ]; then
            $RPARSE -doTrain -train "$TMP/$1/splits/train-$fold.export" -headFinder negra -trainSave "$TMP/$1/grammars/gf-$fold" &> /dev/null \
                || fail_and_cleanup "grammars/$1/gf-$fold"
            $GF --make "$TMP/$1/grammars/gf-$fold/grammargfconcrete.gf" &> /dev/null \
                || fail_and_cleanup "$1/grammars/gf-$fold"
        fi

        if ! [ -f "$TMP/$1/splits/test-$fold-gf.sent" ]; then
            sed 's/^[[:digit:]]\+[[:space:]]\+//' "$TMP/$1/splits/test-$fold.sent" \
                 | sed 's#/[^[:space:]/]\+[[:space:]]# #g' \
                 | sed 's#/[^[:space:]/]\+$# #g' \
                 | sed --file "$SCRIPTS/gf-escapes.sed" \
                 | sed 's#^.\+$#p -bracket "&"#' > "$TMP/$1/splits/test-$fold-gf.sent" \
                || fail_and_cleanup "$1/splits/test-$fold-gf.sent"
        fi
    done
}

function assert_tfcv_rparse_files {
    for fold in {0..9}; do
        if ! [ -f "$TMP/$1/grammars/rparse-train-$fold" ]; then
            $RPARSE -doTrain -train "$TMP/$1/splits/train-$fold.export" -headFinder negra -saveModel "$TMP/$1/grammars/rparse-train-$fold" &> /dev/null \
                || fail_and_cleanup "$1/grammars/rparse-train-$fold"
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

if (( $# > 2 )) && [[ "$3" =~ ^--clean ]]; then
    corpus=`basename $2`
    if [ -d "$RESULTS" ]; then $TRASH "$RESULTS"; fi
    if [ -d "$TMP/$corpus/results" ]; then $TRASH "$TMP/$corpus/results"; fi
    if [[ "$3" =~ ^--clean-all$ ]]; then
        if [ -f "$TMP/$corpus/low-punctuation.export" ]; then $TRASH "$TMP/$corpus/low-punctuation.export"; fi
        if [ -d "$TMP/$corpus/grammars" ]; then $TRASH "$TMP/$corpus/grammars"; fi
        if [ -d "$TMP/$corpus/splits" ]; then $TRASH "$TMP/$corpus/splits"; fi
    fi
fi

if (( $# < 2)) || ! _$1_ $2; then
    echo "use $0 (rustomata|gf|rparse|discolcfrs|discodop|rustomata_dev) <corpus> [--clean-[all]]";
fi