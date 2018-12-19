# Evaluation scripts for Rustomata's mcfg parser

This bunch of scripts was used to evaluate the parse time and accuracy of [Rustomata](https://github.com/tud-fop/rustomata)'s mcfg parser and compare it to three other parsers, namely [rparse](https://github.com/wmaier/rparse), [grammatical framework](https://github.com/gf/gf) and [disco-dop](https://github.com/andreasvc/discodop).

## Requirements

You need python3 for some scripts in the [scripts folder](./scripts/), disco-dop for the computation of the labelled f₁-measure and corpus postprocessing, and some common unix tools (bash, cat, sed, …).
The paths for python3 and disco-dop are set in a configuration file for the use of local installations.
Besides from that the evaluation of
* Rustomata requires Rustomata, and either [vanda-haskell](https://github.com/tud-fop/vanda-haskell) or disco-dop to induce a grammar,
* grammatical framework requires gf and rparse ot induce a grammar, and
* rparse only requires rparse
to be installed.
As for disco-dop, the paths of these binaries are set in a local configuration file.

## Usage

* Copy the template of the configuration file and modify it.
    ```bash
    cp templates/experiments.conf.example experiments.conf
    $EDITOR experiments.conf
    ```
* Run each experiment separately.
  Call [experiments.sh](./experiments.sh) with the parser as first argument and the corpus as second argument.
    ```bash
    bash experiments.sh rparse ~/negra/negra-corpus.export
    ```
* Some parsers may require a third argument, you can find more information about that in „supported parsers“.
  In the case of `discodop`, there are different parsing pipelines implemented. Each one is specified by passing either of `ctf`, `lcfrs` or `dop` additionally, e.g.
    ```bash
    bash experiments.sh discodop ~/negra/negra-corpus.export lcfrs
    ```
* The results are stored in the `$RESULTS` path that was set in `experiments.conf`. E.g. the median parse times for each sentence length of Rustomata using the negra corpus are saved to `$RESULTS/rustomata-negra-corpus.export-times.tsv`.

### Supported parsers

Currently, support for the following parsers is implemented:
* Rustomata's Chomsky-Schützenberger parsing implementation via `rustomata` and one of the following arguments to specify the grammar extraction:
    * `vanda` for a treebank grammar induced using vanda-haskell, or
    * `discodop` for a binarized and markovized grammar using disco-dop.
* disco-dop via `discodop` and one of the following pipeline arguments
    * `lcfrs` for the single lcfrs parser
    * `ctf` for the coarse-to-fine parsing pipeline without DOP (pcfg → plcfrs)
    * `dop` for the default coarse-to-fine parsing pipeline (pcfg → plcfrs → dop)
* rparse via `rparse`
* grammatical framework via `gf`

### Parameters for grammar extraction and parsing

Variable parameters are found in [configuration file](./templates/experiments.conf.example).
Besides settings for important paths and executables, this file is used for the specification of meta-parameters and evaluation parameters for each parser.
By default, we use the evaluation parameters given in the [defaults of disco-dop](templates/discodop-eval.prm) (cf. [disco-dop's documentation](https://discodop.readthedocs.io/en/latest/fileformats.html#evalparam-format)).

#### Rustomata

Probabilistic treebank grammars are induced using vanda-haskell.
This involves neither binarization nor markivization.
By default, we use *candidates* = 10,000 and disable beam search (*beam width* = ∞) for parsing.

#### disco-dop

We use the default values for grammar extraction and parsing for disco-dop:
* disco-dop's sole lcfrs parser extracts binarized and markovized (*h*orizontally: 1, *v*ertically: 1) lcfrs and parses without further pruning,
* disco-dop's coarse-to-fine parser also extracts binarized and markovized grammars and prunes each stage using the results of the stage before.

#### rparse

rparse extracts grammars with default parameters. This involves binarization and markovization (horizontally: 2, vertically: 1).
rparse's timeout can be set in the configuration, by default it is 30 seconds per sentence.

#### GF

The grammar extraction of rparse is used for GF, so default parameters are the same.
We employ a timeout for GF's parser; it can be set in the configuration file, default for this is 30 seconds.

### Grid search

Additionally to the evaluation, there is an implementation of a grid search over a parameter space specified in the config file for Rustomata via `rustomata_dev`.
This grid search iterates over configurations for two parameters: a beam with and a number of considered coarse candidate parses.
Value ranges for both meta-parameters are given in the [configuration file](./templates/experiments.conf.example).
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

## License

This project redistributes some python scripts in [scripts/panda](./scripts/panda/) from [panda-parser](https://github.com/kilian-gebhardt/panda-parser/).
To avoid further dependencies, we omit a submodule and publish this project under terms of the GPL.