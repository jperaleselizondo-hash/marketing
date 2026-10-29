// Turn a raw author/speaker handle into a stable per-organization pseudonym (keyed HMAC). Raw handles are never stored.
// Fails closed if the workspace key MKTENG_PSEUDONYM_KEY is missing.
function "privacy/pseudonymize" {
  input {
    int organization_id
    text? handle?
  }

  stack {
    var $ref {
      value = null
    }
  
    conditional {
      if ((($input.handle ?? "")|trim|strlen) > 0) {
        var $key {
          value = $env.MKTENG_PSEUDONYM_KEY ?? ""
        }
      
        precondition (($key|strlen) >= 32) {
          error = "PSEUDONYMIZATION_UNAVAILABLE: Pseudonymization key is not configured"
        }
      
        var $material {
          value = ($input.organization_id|to_text) ~ ":" ~ ($input.handle|trim|to_lower)
        }
      
        var.update $ref {
          value = "psn_" ~ (($material|hmac_sha256:$key)|substr:0:24)
        }
      }
    }
  }

  response = $ref
  guid = "-Xq2zdbO5BwwkVzK839dzeYKozw"
}