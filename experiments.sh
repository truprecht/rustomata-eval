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
# <RESULTS>/<parser>-<corpus>-time-(mean|median).tsv and discodop's output for the accuracy in
# <RESULTS>/<parser>-<corpus>-scores.txt

# IN:
# - PARAMETERS: $1 – corpus file
# - FILES: $1
# OUT:
# - FILES: $TMP/<basename of $1>/results/rparse-(times.tsv|predictions.export),
#          $RESULTS/rparse-<basename of $1>-(scores|times-(mean|median)).tsv
function _rparse_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_rparse_files "$corpus"

    echo -e "len\ttime\tsuccess" >> "$TMP/$corpus/results/rparse-times.tsv"
    for (( fold=1; fold<=$MAX_EVAL_FOLD; fold++ )); do
        echo "Processing fold $fold/$MAX_EVAL_FOLD... "
        $RPARSE -doParse -test "$TMP/$corpus/splits/test-$fold.export" -testFormat export -readModel "$TMP/$corpus/grammars/rparse-train-$fold" -timeout "$RPARSE_TIMEOUT" \
             > >($PYTHON $SCRIPTS/fill_sentence_id.py "$TMP/$corpus/splits/test-$fold.sent" | $PYTHON $SCRIPTS/fill_noparses.py "$TMP/$corpus/splits/test-$fold.sent" >> "$TMP/$corpus/results/rparse-predictions.export")  \
            2> >($PYTHON $SCRIPTS/parse_rparse_output.py >> "$TMP/$corpus/results/rparse-times.tsv") \
            || fail_and_cleanup "$corpus/results/rparse-predictions.export" "$corpus/results/rparse-times.tsv"
        echo "done."
    done

    $DISCO eval "$TMP/$corpus/splits/test-1-9.export" "$TMP/$corpus/results/rparse-predictions.export" "$DISCODOP_EVAL" \
         > "$RESULTS/rparse-$corpus-scores.txt" \
        || fail_and_cleanup

    $PYTHON $SCRIPTS/averages.py --group=len --mean=time < "$TMP/$corpus/results/rparse-times.tsv" > "$RESULTS/rparse-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=time < "$TMP/$corpus/results/rparse-times.tsv" > "$RESULTS/rparse-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

# IN:
# - PARAMETERS: $1 – corpus file
# - FILES: $1
# OUT:
# - FILES: $TMP/<basename of $1>/results/gf-(times.tsv|predictions.export),
#          $RESULTS/gf-<basename of $1>-(scores|times-(mean|median)).tsv
function _gf_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_gf_files "$corpus"

    echo -e "len\ttime\tsuccess" >> "$TMP/$corpus/results/gf-times.tsv"
    for (( fold=1; fold<=$MAX_EVAL_FOLD; fold++ )); do
        echo "Processing fold $fold/$MAX_EVAL_FOLD... "
        gf_with_timeout "$TMP/$corpus/grammars/gf-$fold/grammargfabstract.pgf" "$TMP/$corpus/splits/test-$fold-gf.sent" \
              | $PYTHON $SCRIPTS/parse_gf_output.py "$TMP/$corpus/splits/test-$fold.sent" \
              > >($PYTHON $SCRIPTS/gf-escapes-rev.py >> "$TMP/$corpus/results/gf-predictions.export") \
            2>> "$TMP/$corpus/results/gf-times.tsv" \
             || fail_and_cleanup "results/gf-predictions.export" "results/gf-times.tsv"
        echo "done."
    done

    $DISCO eval "$TMP/$corpus/splits/test-1-9.export" "$TMP/$corpus/results/gf-predictions.export" "$DISCODOP_EVAL" \
         > "$RESULTS/gf-$corpus-scores.txt" \
        || fail_and_cleanup

    $PYTHON $SCRIPTS/averages.py --group=len --mean=time < "$TMP/$corpus/results/gf-times.tsv" > "$RESULTS/gf-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=time < "$TMP/$corpus/results/gf-times.tsv" > "$RESULTS/gf-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

# IN:
# - PARAMETERS: $1 – corpus file, $2 – pipeline name (ctf|lcfrs|dop)
# - FILES: $1, templates/discodop-$2.prm
# OUT:
# - FILES: $TMP/<basename of $1>/results/discodop-$2-(times.tsv|predictions.export),
#          $RESULTS/discodop-$2-<basename of $1>-(scores|times-(mean|median)).tsv
function _discodop_ {
    if ! ( (( $# == 2 )) && [[ "$2" =~ ^(dop|ctf|lcfrs)$ ]] ); then
        echo "Missing or wrong pipeline argument. Choose either of the following: \"dop\", \"ctf\" or \"lcfrs\"."
        fail_and_cleanup
    fi
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_discodop_files "$corpus" "$2"

    echo -e "sentid\tlen\telapsedtime" > "$TMP/$corpus/results/discodop-$2-times.tsv"
    for (( fold=1; fold<=$MAX_EVAL_FOLD; fold++ )); do
        echo "Processing fold $fold/$MAX_EVAL_FOLD... "
        $DISCO runexp "$TMP/$corpus/grammars/discodop-$2-$fold.prm" &> /dev/null \
            || fail_and_cleanup "grammars/discodop-$2-$fold"

        $PYTHON $SCRIPTS/averages.py --group=sentid --mean=len --sum=elapsedtime < "$TMP/$corpus/grammars/discodop-$2-$fold/stats.tsv" \
            | tail -n+2 >> "$TMP/$corpus/results/discodop-$2-times.tsv"
        cat "$TMP/$corpus/grammars/discodop-$2-$fold/dop.export" >> "$TMP/$corpus/results/discodop-$2-predictions.export"
        echo "done."
    done

    $DISCO eval "$TMP/$corpus/splits/test-1-9.export" "$TMP/$corpus/results/discodop-$2-predictions.export" "$DISCODOP_EVAL" \
         > "$RESULTS/discodop-$2-tfcv-scores.txt" \
        || fail_and_cleanup

    $PYTHON $SCRIPTS/averages.py --group=len --mean=elapsedtime < "$TMP/$corpus/results/discodop-$2-times.tsv" > "$RESULTS/discodop-$2-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=elapsedtime < "$TMP/$corpus/results/discodop-$2-times.tsv" > "$RESULTS/discodop-$2-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

# IN:
# - PARAMETERS: $1 – corpus file, $2 – grammar extraction mechanism (vanda|discodop)
# - FILES: $1
# OUT:
# - FILES: $TMP/<basename of $1>/results/rustomata-$2-(times.tsv|predictions.export),
#          $RESULTS/rustomata-$2-<basename of $1>-(scores|times-(mean|median)).tsv
function _rustomata_ {
    if ! ( (( $# == 2 )) && [[ "$2" =~ ^(vanda|discodop)$ ]] ); then
        echo "Missing or wrong grammar argument. Choose either of the following: \"vanda\" or \"discodop\"."
        fail_and_cleanup
    fi
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_rustomata_files "$corpus" "$2"

    echo -e "grammarsize\tlen\tgrammarsize_after_filtering\ttime\tresult\tcandidates" >> "$TMP/$corpus/results/rustomata-$2-times.tsv"
    for (( fold=1; fold<=$MAX_EVAL_FOLD; fold++ )); do
        echo "Processing fold $fold/$MAX_EVAL_FOLD... "
        $RUSTOMATA csparsing parse "$TMP/$corpus/grammars/train-$2-$fold.cs" --beam=$RUSTOMATA_D_BEAM --candidates=$RUSTOMATA_D_CANDIDATES --with-pos --with-lines --debug < "$TMP/$corpus/splits/test-$fold.sent" \
            2> >(sed 's: :\t:g' >> "$TMP/$corpus/results/rustomata-$2-times.tsv") \
             | sed 's:_[[:digit:]]::' >> "$TMP/$corpus/results/rustomata-$2-predictions.export" \
            || fail_and_cleanup "results/rustomata-$2-times.tsv" "results/rustomata-$2-predictions.export"
        echo "done."
    done

    if [[ "$2" =~ ^discodop$ ]]; then
        mv "$TMP/$corpus/results/rustomata-$2-predictions.export" "$TMP/$corpus/results/rustomata-$2-predictions.export.bin"
        $DISCO treetransforms --unbinarize "$TMP/$corpus/results/rustomata-$2-predictions.export.bin" > "$TMP/$corpus/results/rustomata-$2-predictions.export"
    fi

    $DISCO eval "$TMP/$corpus/splits/test-1-9.export" "$TMP/$corpus/results/rustomata-$2-predictions.export" "$DISCODOP_EVAL" \
        >> "$RESULTS/rustomata-$2-scores.txt" \
        || fail_and_cleanup

    $PYTHON $SCRIPTS/averages.py --group=len --mean=time < "$TMP/$corpus/results/rustomata-$2-times.tsv" >> "$RESULTS/rustomata-$2-$corpus-times-mean.tsv" \
        || fail_and_cleanup
    $PYTHON $SCRIPTS/averages.py --group=len --median=time < "$TMP/$corpus/results/rustomata-$2-times.tsv" >> "$RESULTS/rustomata-$2-$corpus-times-median.tsv" \
        || fail_and_cleanup
}

# this section contains the function to evaluate the meta-parameters for
# rustomata, the results are stored in $RESULTS/rustomata-ofcv-scores.tsv and
# $RESULTS/rustomata-ofcv-times-(mean|median).tsv
# IN:
# - PARAMETERS: $1 – corpus file
# - FILES: $1
# OUT:
# - FILES: $TMP/<basename of $1>/results/rustomata-ofcv-$BEAM-$CAN-(times.tsv|predictions.export)
#          where $BEAM is one of $RUSTOMATA_BEAMS and $CAN is one of $RUSTOMATA_CANDIDATES,
#          $RESULTS/rustomata-ofcv-<basename of $1>-(scores|times-(median|mean)).tsv
function _rustomata_dev_ {
    corpus=`basename $1`
    assert_folder_structure "$corpus"
    assert_corpus_files "$1" "$corpus"
    assert_tfcv_rustomata_files "$corpus" "vanda"

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
            $DISCO eval $TMP/$corpus/splits/test-0.export $TMP/$corpus/results/rustomata-ofcv-$beam-$cans-predictions.export "$DISCODOP_EVAL" \
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

# wraps `/bin/timeout` around gf to support some basic timeout implementation
# IN:
# - PARAMETERS: $1 – gf grammar file, $2 – gf script file
# - FILES: $1, $2
# OUT:
# - STDOUT: gf output and output in the same form as gf if a timeout occurred
function gf_with_timeout {
    while read sentence || [ -n "$sentence" ]; do
        # the following line echos a gf command pipeline which
        # * parses the sentence,
        # * visualizes the parse trees (prints it in dot format), and
        # * calls a python script that takes only the first tree
        # into grammatical framework wrapped in `timeout`.
        sentenceoutput="$(echo "p \"$sentence\" | vp | sp -command=\"$PYTHON $SCRIPTS/take_first_gf_tree.py\"" | timeout $GF_TIMEOUT $GF $1)"
        ec=$?                           # handle errorcode of `timeout`
        if (( $ec == 124 )); then       # timeout
            echo "TIMEOUT>"
            echo "${GF_TIMEOUT}000 msec"
        elif (( $ec != 0 )); then       # some other error
            return $ec
        else                            # no error, propagate output
            echo "$sentenceoutput" | grep -P -A1 '^[^>]+>' | head -n2 | sed 's:[^>]\+>[[:space:]]*::'
        fi
    done <"$2"
}


# IN:
# - PARAMETERS: $1 – corpus name
# OUT:
# - FILES: $TMP/$1/(splits|grammars/results)/, $RESULTS
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
        echo "#FORMAT 4" > "$TMP/$2/low-punctuation.export"
        $DISCO treetransforms --punct=move "$1" >> "$TMP/$2/low-punctuation.export" \
            || fail_and_cleanup "$2/low-punctuation.export"
    fi
    if ! [ -f "$TMP/$2/splits/test-0.export" ]; then
        $PYTHON $SCRIPTS/tfcv.py "$TMP/$2/low-punctuation.export" --out-prefix="$TMP/$2/splits" --max-length=$MAXLENGTH --fix-bos=true
    fi
    if ! [ -f "$TMP/$2/splits/test-1-9.export" ]; then
        echo "#FORMAT 4" > "$TMP/$2/splits/test-1-9.export"
        for (( fold=1; fold<=$MAX_EVAL_FOLD; fold++ )); do
            tail -n+2 "$TMP/$2/splits/test-$fold.export" >> "$TMP/$2/splits/test-1-9.export"
            echo "" >> "$TMP/$2/splits/test-1-9.export"
        done
    fi
}

# IN:
# - PARAMETERS: $1 – corpus name, $2 – grammar extraction mechanism (vanda|discodop)
# - FILES: $TMP/$1/splits/train-(0|…|9).export or $TMP/$1/splits/train-$2.export (if $2 is given)
# OUT:
# - FILES: $TMP/$1/grammars/train-$2-(0|…|9).cs
function assert_tfcv_rustomata_files {
    if [[ "$2" =~ ^discodop$ ]]; then assert_tfcv_discodop_files "$1" "lcfrs"; fi

    for (( fold=0; fold<=$MAX_EVAL_FOLD; fold++ )); do
        if ! [ -f "$TMP/$1/grammars/train-$2-$fold.cs" ]; then
            if [[ "$2" =~ ^discodop$ ]]; then
                $DISCO grammar param "$TMP/$1/grammars/discodop-lcfrs-$fold.prm" "$TMP/$1/grammars/train-$fold.discodop" &> /dev/null \
                    || fail_and_cleanup "$TMP/$1/grammars/train-$fold.discodop"
                # begin:  replace the PoS-Tag $[ by $(, as used in the NeGra-Corpus
                gunzip -c "$TMP/$1/grammars/train-$fold.discodop/plcfrs.rules.gz" | sed 's/\$\[/\$\(/g' | gzip > "$TMP/$1/grammars/train-$fold.discodop/plcfrs.rules-fixed.gz"
                $RUSTOMATA csparsing extract -d "$TMP/$1/grammars/train-$fold.discodop/plcfrs.rules-fixed.gz" > "$TMP/$1/grammars/train-discodop-$fold.cs" \
                    || fail_and_cleanup "$TMP/$1/grammars/train-discodop-$fold.cs"

            elif [[ "$2" =~ ^vanda$ ]]; then
                $VANDA pmcfg extract -p "$TMP/$1/grammars/train-$fold.vanda" < "$TMP/$1/splits/train-$fold.export" \
                    || fail_and_cleanup
                $RUSTOMATA csparsing extract < "$TMP/$1/grammars/train-$fold.vanda.readable" > "$TMP/$1/grammars/train-vanda-$fold.cs" \
                    || fail_and_cleanup "$1/grammars/train-vanda-$fold.cs"

            fi
        fi
    done
}

# IN:
# - PARAMETERS: $1 – corpus name, $2 – pipeline name (lcfrs|dop|ctf)
# - FILES: templates/discodop-(dop|ctf|lcfrs).prm
# OUT:
# - FILES: $TMP/$1/grammars/discodop-(dop|ctf|lcfrs)-(0|..|9).prm
function assert_tfcv_discodop_files {
    for (( fold=0; fold<=$MAX_EVAL_FOLD; fold++ )); do
        if ! [ -f "$TMP/$1/grammars/discodop-$2-$fold.prm" ]; then
            sed "s:{TRAIN}:$TMP/$1/splits/train-$fold.export:" "templates/discodop-$2.prm" \
                | sed "s:{TEST}:$TMP/$1/splits/test-$fold.export:" \
                | sed "s:{MAXLENGTH}:$MAXLENGTH:" \
                | sed "s:{EVALFILE}:$DISCODOP_EVAL:" > "$TMP/$1/grammars/discodop-$2-$fold.prm"
        fi
    done
}

# IN:
# - PARAMETERS: $1 – corpus name
# - FILES: $TMP/$1/splits/train-(0|..|9).export, $TMP/$1/splits/test-(0|..|9).sent
# OUT:
# - FILES: $TMP/$1/grammars/gf-(0|..|9)/*, $TMP/$1/splits/test-(0|..|9)-gf.sent
function assert_tfcv_gf_files {
    if ! [ -d "$TMP/$1/grammars/gf-all" ]; then
        $RPARSE -doTrain -train "$TMP/$1/low-punctuation.export" -headFinder negra -trainSave "$TMP/$1/grammars/gf-all" &> /dev/null \
            || fail_and_cleanup "grammars/$1/gf-all"
    fi
    for (( fold=1; fold<=$MAX_EVAL_FOLD; fold++ )); do
        if ! [ -d "$TMP/$1/grammars/gf-$fold" ]; then
            $RPARSE -doTrain -train "$TMP/$1/splits/train-$fold.export" -headFinder negra -trainSave "$TMP/$1/grammars/gf-$fold" &> /dev/null \
                || fail_and_cleanup "grammars/$1/gf-$fold"

            # copy lexer from complete corpus, such that all terminals are available
            cp "$TMP/$1/grammars/gf-all/grammargf.lex" "$TMP/$1/grammars/gf-$fold/grammargf.lex"
            cp "$TMP/$1/grammars/gf-all/grammargflexconcrete.gf" "$TMP/$1/grammars/gf-$fold/grammargflexconcrete.gf"
            cp "$TMP/$1/grammars/gf-all/grammargflexabstract.gf" "$TMP/$1/grammars/gf-$fold/grammargflexabstract.gf"
            # copy lexer probabilities from complete corpus
            grep -vP "^fun\d+" "$TMP/$1/grammars/gf-all/grammargf.probs" > "$TMP/$1/grammars/gf-$fold/grammargf.probs1"
            grep -P "^fun\d+" "$TMP/$1/grammars/gf-$fold/grammargf.probs" >> "$TMP/$1/grammars/gf-$fold/grammargf.probs1"
            mv "$TMP/$1/grammars/gf-$fold/grammargf.probs1" "$TMP/$1/grammars/gf-$fold/grammargf.probs"

            $GF --probs="$TMP/$1/grammars/gf-$fold/grammargf.probs" --make -D "$TMP/$1/grammars/gf-$fold/" "$TMP/$1/grammars/gf-$fold/grammargfconcrete.gf" &> /dev/null \
                || fail_and_cleanup "$1/grammars/gf-$fold"
        fi

        if ! [ -f "$TMP/$1/splits/test-$fold-gf.sent" ]; then
            sed 's/^[[:digit:]]\+[[:space:]]\+//' "$TMP/$1/splits/test-$fold.sent" \
                 | sed 's#/[^[:space:]/]\+[[:space:]]# #g' \
                 | sed 's#/[^[:space:]/]\+$# #g' \
                 | sed --file "$SCRIPTS/gf-escapes.sed" > "$TMP/$1/splits/test-$fold-gf.sent" \
                || fail_and_cleanup "$1/splits/test-$fold-gf.sent"
        fi
    done
}

# IN:
# - PARAMETERS: $1 – corpus name
# - FILES: $TMP/$1/splits/train-(0|..|9).export
# OUT:
# - FILES: $TMP/$1/grammars/rparse-train-(0|..|9)/
function assert_tfcv_rparse_files {
    for (( fold=1; fold<=$MAX_EVAL_FOLD; fold++ )); do
        if ! [ -f "$TMP/$1/grammars/rparse-train-$fold" ]; then
            $RPARSE -doTrain -train "$TMP/$1/splits/train-$fold.export" -headFinder negra -saveModel "$TMP/$1/grammars/rparse-train-$fold" &> /dev/null \
                || fail_and_cleanup "$1/grammars/rparse-train-$fold"
        fi
    done
}

# IN:
# - PARAMETERS: $* files or folders to remove with $TRASH before exiting
function fail_and_cleanup {
    for f in $@; do
        if [ -d "$TMP/$f" ] || [ -f "$TMP/$f" ]; then
            $TRASH "$TMP/$f"
        fi
    done

    exit 1
}

function _clean_ {
    corpus=`basename $1`
    if [ -d "$RESULTS" ]; then $TRASH "$RESULTS"; fi
    if [ -d "$TMP/$corpus/results" ]; then $TRASH "$TMP/$corpus/results"; fi
}

function _clean-all_ {
    _clean_ $1
    corpus=`basename $1`
    if [ -f "$TMP/$corpus/low-punctuation.export" ]; then $TRASH "$TMP/$corpus/low-punctuation.export"; fi
    if [ -d "$TMP/$corpus/grammars" ]; then $TRASH "$TMP/$corpus/grammars"; fi
    if [ -d "$TMP/$corpus/splits" ]; then $TRASH "$TMP/$corpus/splits"; fi
}

if ! (( $# > 1 )) \
|| ! [[ "$1" =~ ^(rustomata|gf|rparse|discodop|rustomata_dev|clean(-all)?)$ ]] \
|| ! [ -f "$2" ]; then
    echo "use $0 (rustomata|gf|rparse|discodop|rustomata_dev|clean[-all]) <corpus> [<additional parser argument>]";
else
    if (( $# > 2 )); then _$1_ $2 $3; else _$1_ $2; fi
fi
