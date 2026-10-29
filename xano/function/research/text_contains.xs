// Whitespace-insensitive check that an excerpt appears verbatim in stored source content.
function "research/text_contains" {
  input {
    text? haystack?
    text needle
  }

  stack {
    var $hay {
      value = "/[[:space:]]+/"
        |regex_replace:" ":$input.haystack ?? ""
    }
  
    var $needle {
      value = "/[[:space:]]+/"|regex_replace:" ":$input.needle
    }
  
    var $found {
      value = (($needle|trim)|strlen) > 0 && ($hay|contains:($needle|trim))
    }
  }

  response = $found
  guid = "EtgSk1QFOe-CisEkfgbc6mjLZHw"
}