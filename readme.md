# Evaluation scripts for Rustomata's mcfg parser

This bunch of scripts was used to evaluate the parse time and accuracy of [Rustomata](https://github.com/tud-fop/rustomata)'s mcfg parser and compare it to three other parsers, namely [rparse](https://github.com/wmaier/rparse), [grammatical framework](https://github.com/gf/gf) and [disco-dop](https://github.com/andreasvc/discodop).

## Requirements

You need python3 for some scripts in the [scripts folder](./scripts/), disco-dop for the computation of the labelled f₁-measure and corpus postprocessing, and some common unix tools (bash, cat, sed, …).
The paths for python3 and disco-dop are set in a configuration file for the use of local installations.
Besides from that the evaluation of
* Rustomata requires Rustomata, and [vanda-haskell](https://github.com/tud-fop/vanda-haskell),
* grammatical framework requires gf and rparse, and
* rparse only requires rparse
to be installed.
As for disco-dop, the paths of these binaries are set in a local configuration file.

## Usage

* Copy the template of the configuration file and modify it.
    ```bash
    cp templates/experiments.conf.example experiments.conf
    $EDITOR experiments.conf
    ```
* Run each experiment separately. Call `experiments.sh` with the parser as first argument and the corpus as second argument.
    ```bash
    bash experiments.sh rustomata ~/negra/negra-corpus.export
    ```
* The results are stored in the `$RESULTS` path that was set in `experiments.conf`. E.g. the median parse times for each sentence length of Rustomata using the negra corpus are saved to `$RESULTS/rustomata-negra-corpus.export-times.tsv`.

### Supported parsers

Currently, support for the following parsers is implemented:
* Rustomata's Chomsky-Schützenberger parsing implementation via `rustomata`
* disco-dop's default coarse-to-fine parsing pipeline via `discodop`
* disco-dop's lcfrs parser vial `discolcfrs`
* rparse via `rparse`
* grammatical framework via `gf`

### Grid search

Additionally to the evaluation, there is an implementation of a grid search over a parameter space specified in the config file for Rustomata via `rustomata_dev`.
This grid search iterates over configurations for two parameters: a beam with and a number of considered coarse candidate parses.
The results for each combination of configurations are stored in `$RESULTS/rustomata-ofcv-<corpus>-scores.tsv` and `$RESULTS/rustomata-ofcv-<corpus>-times-median.tsv`.

### Supported corpora

This should work with every corpus in [export format](http://www.coli.uni-sb.de/~thorsten/publications/Brants-CLAUS98.ps.gz) and was tested with [NeGra](http://www.coli.uni-saarland.de/projects/sfb378/negra-corpus/negra-corpus.html) and a converted version of [Lassy Small](http://www.let.rug.nl/~vannoord/Lassy/).
Lassy was originally given in xml and [converted using disco-dop](https://discodop.readthedocs.io/en/latest/cli/treetransforms.html) into export format.

## How the evaluation works

The implementation of the evaluation using these scripts consists of
1. corpus postprocessing (moving the punctuation in gold trees using [disco-dop's tree transformations](https://discodop.readthedocs.io/en/latest/cli/treetransforms.html)),
2. extraction of one test split (training and test set) and nine evaluation splits (training and evaluation set) from the given corpus,
3. extraction of a grammar for each training set,
4. parsing each evaluation set using the grammar extracted from the corresponding training set, and collecting the parse times, and
5. evaluate the parses using the gold parse trees of the parsed evaluation splits.

The grid search for Rustomata uses the test split from step 3 and parses the test set using a grammar extracted from the corresponding training set.