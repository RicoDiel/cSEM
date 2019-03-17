
<!-- README.md is generated from README.Rmd. Please edit that file -->

# cSEM: a package for composite-based SEM

[![CRAN
status](https://www.r-pkg.org/badges/version/cSEM)](https://cran.r-project.org/package=cSEM)

WARNING: THIS IS WORK IN PROGRESS. BREAKING CHANGES TO THE API ARE VERY
LIKELY. Do not use the package before the first stable relase (which
will be 0.0.1, most likely in mid 2019).

## Purpose

Estimate, analyse, test, and study linear, nonlinear, hierachical and
multigroup structural equation models using composite-based approaches
and procedures including estimation techniques such as partial least
squares path modelling (PLS) and its derivatives (PLSc, ordPLSc,
robustPLSc), generalized structured component analysis (GSCA),
generalized structured component analysis with uniqueness terms (GSCAm),
generalized canonical correlation analysis (GCCA), unit weights (sum
score) and fixed weights, as well as several tests and typical
postestimation procedures (e.g., assess the model fit, compute direct,
indirect and total effects).

## Installation

``` r
# Currently only a development version from GitHub is available:
# install.packages("devtools")
devtools::install_github("M-E-Rademaker/cSEM")
```

## Philopsophy

  - User-centred\!\!
  - Easy to use by non-R experts:
      - One central function `csem()` provides default choices for most
        of its arguments (similarity to the `sem()` and `cfa()`
        functions of the [lavaan](http://lavaan.ugent.be/) package is
        intended).
      - (Eventually…) well documented (Vignettes, HTML output, a
        website, intro course(s), cheatsheets)
      - Structured output/results that aims to be “easy”" in a sense
        that it is
          - … descriptive/verbose
          - … easy to export to other environments such as MS Word,
            Latex files etc. (exportability)
          - … easy to migrate from/to/between other PLS/VB/CB-based
            systems (lavaan, semPLS, ADANCO, SmartPLS)
  - The package is designed to be flexible/modular enough so that
    researchers developing new methods can take specific function
    provided by the package and alter them according to their need
    without working their way through a chain of other functions
    (naturally this will not always be possible). Modularity is largly
    inspired by the `matrixpls` package.
  - Modern in a sense that the package integrates modern developments
    within the R community. This mainly includes
    ideas/recommendations/design choices that fead into the packages of
    the [tidyverse](https://github.com/tidyverse/tidyverse).

## Basic usage

Models are defined using [lavaan
syntax](http://lavaan.ugent.be/tutorial/syntax1.html) with some slight
modification.

``` r
require(cSEM)
data(satisfaction)
    
## Note: the opeartor "<~" tells cSEM that the construct to its left is modelled
##       as a composite.
##       the operator "=~" tells cSEM that the construct to its left is modelled
##       as a common factor.
    
model <- "
# Structural model
EXPE ~ IMAG
QUAL ~ EXPE
VAL  ~ EXPE + QUAL
SAT  ~ IMAG + EXPE + QUAL + VAL 
LOY  ~ IMAG + SAT

# Measurement model

IMAG <~ imag1 + imag2 + imag3
EXPE <~ expe1 + expe2 + expe3 
QUAL <~ qual1 + qual2 + qual3 + qual4 + qual5
VAL  <~ val1  + val2  + val3
SAT  =~ sat1  + sat2  + sat3  + sat4
LOY  =~ loy1  + loy2  + loy3  + loy4
"
```

Estimation is done using the `csem()` function.

``` r
# Estimate using defaults
a <- csem(.data = satisfaction, .model = model)

# This is equal to
csem(
   .data                        = NULL,
   .model                       = NULL,
   .approach_cor_robust         = "none",
   .approach_nl                 = "sequential",
   .approach_paths              = "OLS",
   .approach_weights            = "PLS-PM",
   .conv_criterion              = "diff_absolute",
   .disattenuate                = TRUE,
   .dominant_indicators         = NULL,
   .estimate_structural         = TRUE,
   .id                          = NULL,
   .iter_max                    = 100,
   .normality                   = TRUE,
   .PLS_approach_cf             = "dist_squared_euclid",
   .PLS_ignore_structural_model = FALSE,
   .PLS_modes                   = NULL,
   .PLS_weight_scheme_inner     = "path",
   .reliabilities               = NULL,
   .tolerance                   = 1e-05,
   .resample_method             = "none", 
   .resample_method2            = "none",
   .R                           = 499,
   .R2                          = 199,
   .handle_inadmissibles        = "drop"
   .user_funs                   = NULL,
   .eval_plan                   = "sequential",
   .seed                        = NULL
    )
```

The result is always an object of class `cSEMResults`. Technically, the
resulting object has an additional class attribute (namely
`cSEMResults_default`, `cSEMResults_multi` or `cSEMResults_2ndorder`),
however, users usually dont need to worry since postestimation functions
(will eventually) automatically work on all classes.

``` r
## Access elements using `$`. E.g.:
a$Estimates$Loading_estimates 
a$Information$Model
    
## Examine the structure:
listviewer::jsonedit(a, mode = "view") # requires the listviewer package.
    
## Get a summary
summarize(a) 
    
# Alter the model to obtain a linear model:
model <- "
    # Structural model
    EXPE ~ IMAG
    QUAL ~ EXPE
    VAL  ~ EXPE + QUAL
    SAT  ~ IMAG + EXPE + QUAL + VAL
    LOY  ~ IMAG + SAT
    
    # Measurement model
    
    IMAG <~ imag1 + imag2 + imag3
    EXPE <~ expe1 + expe2 + expe3 
    QUAL <~ qual1 + qual2 + qual3 + qual4 + qual5
    VAL  <~ val1  + val2  + val3
    SAT  =~ sat1  + sat2  + sat3  + sat4
    LOY  =~ loy1  + loy2  + loy3  + loy4
    "
    
a <- csem(.data = satisfaction, .model = model)
    
## Apply postestimation functions, e.g.
verify(a) 
    
## Test overall model fit
testOMF(a) # takes roughly 30 seconds
```

Inference can be done by first setting `.resample_method` to
`"jackkinfe"` or `"bootstrap"` and subsequently using `summarize()` or
`infer()`.

``` r
b <- csem(.data = satisfaction, .model = model, .resample_method = "bootstrap")
summarize(b)

## Several confidence intervals are implemented, see ?infer():

infer(b, .quantity = c("CI_standard_z", "CI_percentile"))
```
