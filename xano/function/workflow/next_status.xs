// Shared review state machine: candidate -> in_review -> approved | rejected; approved|rejected -> candidate (reopen).
// submit needs editor; approve/reject/reopen need reviewer; reject and reopen need a reason.
function "workflow/next_status" {
  input {
    text current_status
    text decision
    int rank
    text? reason?
  }

  stack {
    var $allowed_from {
      value = {
        submit : ["candidate"]
        approve: ["candidate", "in_review"]
        reject : ["candidate", "in_review"]
        reopen : ["approved", "rejected"]
      }
    }
  
    var $targets {
      value = {
        submit : "in_review"
        approve: "approved"
        reject : "rejected"
        reopen : "candidate"
      }
    }
  
    var $min_rank {
      value = {submit: 2, approve: 3, reject: 3, reopen: 3}
    }
  
    precondition ($targets|has:$input.decision) {
      error_type = "inputerror"
      error = "INVALID_DECISION: decision must be submit, approve, reject or reopen"
    }
  
    precondition ($input.rank >= ($min_rank|get:$input.decision)) {
      error_type = "accessdenied"
      error = "FORBIDDEN: Your role cannot " ~ $input.decision ~ " this item"
    }
  
    precondition (($allowed_from|get:$input.decision)|in:$input.current_status) {
      error_type = "inputerror"
      error = "INVALID_TRANSITION: cannot " ~ $input.decision ~ " from " ~ $input.current_status
    }
  
    precondition (($input.decision != "reject" && $input.decision != "reopen") || (($input.reason ?? "")|strlen) > 0) {
      error_type = "inputerror"
      error = "REASON_REQUIRED: reject and reopen need a reason"
    }
  }

  response = $targets|get:$input.decision
  guid = "IYC9foMVNOovqZ0VnKmu_Ivp_ME"
}