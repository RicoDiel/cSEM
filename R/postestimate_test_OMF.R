#' Test for overall model fit
#'
#' Bootstrap-based test for overall model fit originally proposed by \insertCite{Beran1985;textual}{cSEM}. 
#' See also \insertCite{Dijkstra2015;textual}{cSEM} who first suggested the test in 
#' the context of PLS-PM.
#' 
#' `testOMF()` tests the null hypothesis that the population indicator 
#' correlation matrix equals the population model-implied indicator correlation matrix. 
#' Several potential test statistics may be used. `testOMF()` uses three distance
#' measures to assess the distance between the sample indicator correlation matrix
#' and the estimated model-implied indicator correlation matrix, namely the geodesic distance, 
#' the squared Euclidean distance, and the standardized root mean square residual (SRMR). 
#' The reference distribution for each test statistic is obtained by 
#' the bootstrap as proposed by \insertCite{Beran1985;textual}{cSEM}. 
#' 
#' If `.saturated = TRUE` the original structural model is ignored and replaced by
#' a saturated model, i.e. a model in which all constructs are allowed to correlate freely. 
#' This is useful to test misspecification of the measurement model in isolation.
#' 
#' @usage testOMF(
#'  .object                = NULL, 
#'  .alpha                 = 0.05, 
#'  .handle_inadmissibles  = c("drop", "ignore", "replace"), 
#'  .R                     = 499, 
#'  .saturated             = FALSE,
#'  .seed                  = NULL,
#'  .verbose               = TRUE
#' )
#' 
#' @inheritParams  csem_arguments
#' 
#' @return
#' A list of class `cSEMTestOMF` containing the following list elements:
#' \describe{
#'   \item{`$Test_statistic`}{The value of the test statistics.}
#'   \item{`$Critical_value`}{The corresponding  critical values obtained by the bootstrap.}
#'   \item{`$Decision`}{The test decision. One of: `FALSE` (**Reject**) or `TRUE` (**Do not reject**).}
#'   \item{`$Information`}{The `.R` bootstrap values; The number of admissible results;
#'                         The seed used and the number of total runs.}
#' }
#' 
#' @seealso [csem()], [calculateSRMR()], [calculateDG()], [calculateDL()], [cSEMResults],
#'   [testMICOM()], [testMGD()]
#' 
#' @references
#'   \insertAllCited{}
#'   
#' @example inst/examples/example_testOMF.R
#' 
#' @export

testOMF <- function(
  .object                = NULL, 
  .alpha                 = 0.05, 
  .handle_inadmissibles  = c("drop", "ignore", "replace"), 
  .R                     = 499, 
  .saturated             = FALSE,
  .seed                  = NULL,
  .verbose               = TRUE
) {
  
  # Implementation is based on:
  # Dijkstra & Henseler (2015) - Consistent Paritial Least Squares Path Modeling
  
  ## Match arguments
  .handle_inadmissibles <- match.arg(.handle_inadmissibles)
  
  if(inherits(.object, "cSEMResults_default")) {
    
    x11 <- .object$Estimates
    x12 <- .object$Information
    
    # Select only columns that are not repeated indicators
    selector <- !grepl("_2nd_", colnames(x12$Model$measurement))
    
    ## Collect arguments
    arguments <- x12$Arguments
    
  } else if(inherits(.object, "cSEMResults_multi")) {
    
    out <- lapply(.object, testOMF,
                  .alpha                = .alpha,
                  .handle_inadmissibles = .handle_inadmissibles,
                  .R                    = .R,
                  .saturated            = .saturated,
                  .seed                 = .seed,
                  .verbose              = .verbose
    )
    ## Return
    return(out)
    
  } else if(inherits(.object, "cSEMResults_2ndorder")) { 
    
    x11 <- .object$First_stage$Estimates
    x12 <- .object$First_stage$Information
    
    x21 <- .object$Second_stage$Estimates
    x22 <- .object$Second_stage$Information
    
    # Select only columns that are not repeated indicators
    selector <- !grepl("_2nd_", colnames(x12$Model$measurement))
    
    ## Collect arguments
    arguments <- x22$Arguments_original
    
    ## Append the 2ndorder approach to args
    arguments$.approach_2ndorder <- x22$Approach_2ndorder
    
  } else {
    stop2(
      "The following error occured in the testOMF() function:\n",
      "`.object` must be a `cSEMResults` object."
    )
  }
  
  if(.verbose) {
    cat(rule2("Test for overall model fit based on Beran & Srivastava (1985)",
              type = 3), "\n\n")
  }
  
  ### Checks and errors ========================================================
  ## Check if initial results are inadmissible
  if(sum(unlist(verify(.object))) != 0) {
    stop2(
      "The following error occured in the `testOMF()` function:\n",
      "Initial estimation results are inadmissible. See `verify(.object)` for details.")
  }
  
  # Return error if used for ordinal variables
  if(any(x12$Type_of_indicator_correlation %in% c("Polyserial", "Polychoric"))){
    stop2(
      "The following error occured in the `testOMF()` function:\n",
      "Test for overall model fit currently not applicable if polychoric or",
      " polyserial correlation is used.")
  }
  
  ### Preparation ==============================================================
  ## Extract required information 
  X         <- x12$Data
  S         <- x11$Indicator_VCV
  Sigma_hat <- fit(.object,
                   .saturated = .saturated,
                   .type_vcv  = "indicator")
  
  # Prune S and X, Sigma_hat is already pruned
  S <- S[selector, selector]
  X <- X[, selector]
  Sigma_hat <- Sigma_hat
  
  ## Calculate test statistic
  teststat <- c(
    "dG"   = calculateDG(.matrix1 = S, .matrix2 = Sigma_hat),
    "SRMR" = calculateSRMR(.matrix1 = S, .matrix2 = Sigma_hat),
    "dL"   = calculateDL(.matrix1 = S, .matrix2 = Sigma_hat)
  )
  
  ## Transform dataset, see Beran & Srivastava (1985)
  S_half   <- solve(expm::sqrtm(S))
  Sig_half <- expm::sqrtm(Sigma_hat)
  
  X_trans           <- X %*% S_half %*% Sig_half
  colnames(X_trans) <- colnames(X)
  
  # Start progress bar if required
  if(.verbose){
    pb <- txtProgressBar(min = 0, max = .R, style = 3)
  }
  
  # Save old seed and restore on exit! This is important since users may have
  # set a seed before, in which case the global seed would be
  # overwritten if not explicitly restored
  old_seed <- .Random.seed
  on.exit({.Random.seed <<- old_seed})
  
  ## Create seed if not already set
  if(is.null(.seed)) {
    set.seed(seed = NULL)
    # Note (08.12.2019): Its crucial to call set.seed(seed = NULL) before
    # drawing a random seed out of .Random.seed. If set.seed(seed = NULL) is not
    # called sample(.Random.seed, 1) would result in the same random seed as
    # long as .Random.seed remains unchanged. By resetting the seed we make 
    # sure that sample draws a different element everytime it is called.
    .seed <- sample(.Random.seed, 1)
  }
  ## Set seed
  set.seed(.seed)
  
  ### Start resampling =========================================================
  ## Calculate reference distribution
  ref_dist         <- list()
  n_inadmissibles  <- 0
  counter <- 0
  repeat{
    # Counter
    counter <- counter + 1
    
    # Draw dataset
    X_temp <- X_trans[sample(1:nrow(X), replace = TRUE), ]

    # Replace the old dataset by the new one
    arguments[[".data"]] <- X_temp
    
    # Estimate model
    Est_temp <- if(inherits(.object, "cSEMResults_2ndorder")) {
      
      do.call(csem, arguments) 
      
    } else {

      do.call(foreman, arguments)
    }           
    
    # Check status (Note: output of verify for second orders is a list)
    status_code <- sum(unlist(verify(Est_temp)))
    
    # Distinguish depending on how inadmissibles should be handled
    if(status_code == 0 | (status_code != 0 & .handle_inadmissibles == "ignore")) {
      # Compute if status is ok or .handle inadmissibles = "ignore" AND the status is 
      # not ok
        
      if(inherits(.object, "cSEMResults_default")) {
        S_temp         <- Est_temp$Estimates$Indicator_VCV
      } else if(inherits(.object, "cSEMResults_2ndorder")) { 
        S_temp         <- Est_temp$First_stage$Estimates$Indicator_VCV
      }
      
      Sigma_hat_temp <- fit(Est_temp,
                            .saturated = .saturated,
                            .type_vcv  = "indicator")
      
      ## Prune S_temp (Sigma_hat is already pruned)
      S_temp <- S_temp[selector, selector]
      
      # Standard case when there are no repeated indicators
      ref_dist[[counter]] <- c(
        "dG"   = calculateDG(.matrix1 = S_temp, .matrix2 = Sigma_hat_temp),
        "SRMR" = calculateSRMR(.matrix1 = S_temp, .matrix2 = Sigma_hat_temp),
        "dL"   = calculateDL(.matrix1 = S_temp, .matrix2 = Sigma_hat_temp)
      ) 

    } else if(status_code != 0 & .handle_inadmissibles == "drop") {
      # Set list element to zero if status is not okay and .handle_inadmissibles == "drop"
      ref_dist[[counter]] <- NA
      
    } else {# status is not ok and .handle_inadmissibles == "replace"
      # Reset counter and raise number of inadmissibles by 1
      counter <- counter - 1
      n_inadmissibles <- n_inadmissibles + 1
    }
    
    # Update progress bar
    if(.verbose){
      setTxtProgressBar(pb, counter)
    }
    
    # Break repeat loop if .R results have been created.
    if(length(ref_dist) == .R) {
      break
    }
  } # END repeat 
  
  # close progress bar
  if(.verbose){
    close(pb)
  }
  
  # Delete potential NA's
  ref_dist1 <- Filter(Negate(anyNA), ref_dist)
  
  # Check if at least 3 admissible results were obtained
  n_admissibles <- length(ref_dist1)
  if(n_admissibles < 3) {
    stop2("The following error occured in the `testOMF()` functions:\n",
         "Less than 2 admissible results produced.", 
         " Consider setting `.handle_inadmissibles == 'replace'` instead.")
  }
  
  # Combine
  ref_dist_matrix <- do.call(cbind, ref_dist1) 
  ## Compute critical values (Result is a (3 x p) matrix, where p is the number
  ## of quantiles that have been computed (1 by default)
  .alpha <- .alpha[order(.alpha)]
  critical_values <- matrixStats::rowQuantiles(ref_dist_matrix, 
                                               probs =  1-.alpha, drop = FALSE)
  
  ## Compare critical value and teststatistic
  decision <- teststat < critical_values # a logical (3 x p) matrix with each column
  # representing the decision for one
  # significance level. TRUE = no evidence 
  # against the H0 --> not reject
  # FALSE --> reject
  
  # Return output
  out <- list(
    "Test_statistic"     = teststat,
    "Critical_value"     = critical_values, 
    "Decision"           = decision, 
    "Information"        = list(
      "Bootstrap_values"   = ref_dist,
      "Number_admissibles" = ncol(ref_dist_matrix),
      "Seed"               = .seed,
      "Total_runs"         = counter + n_inadmissibles
    )
  )
  
  ## Set class and return
  class(out) <- "cSEMTestOMF"
  return(out)
}