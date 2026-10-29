// Evidence counts for an insight from its approved support links. Counts describe the collected sample only,
// never market prevalence. Independence uses distinct source ids and distinct pseudonymous speaker refs.
function "synthesis/evidence_counts" {
  input {
    int insight_id
  }

  stack {
    db.query insight_support {
      where = $db.insight_support.insight_id == $input.insight_id && $db.insight_support.review_status == "approved"
      return = {type: "list"}
    } as $links
  
    var $evidence_count {
      value = 0
    }
  
    var $contradict_count {
      value = 0
    }
  
    var $source_ids {
      value = []
    }
  
    var $speaker_refs {
      value = []
    }
  
    foreach ($links) {
      each as $link {
        conditional {
          if ($link.stance == "contradict") {
            math.add $contradict_count {
              value = 1
            }
          }
        
          else {
            math.add $evidence_count {
              value = 1
            }
          
            db.get research_observations {
              field_name = "id"
              field_value = $link.observation_id
            } as $obs
          
            var $speaker {
              value = $obs.speaker_ref
            }
          
            conditional {
              if ($obs.source_excerpt_id != null) {
                db.get source_excerpts {
                  field_name = "id"
                  field_value = $obs.source_excerpt_id
                } as $excerpt
              
                conditional {
                  if ($excerpt != null) {
                    var.update $source_ids {
                      value = $source_ids|push:$excerpt.source_id
                    }
                  
                    conditional {
                      if ($speaker == null) {
                        var.update $speaker {
                          value = $excerpt.speaker_ref
                        }
                      }
                    }
                  }
                }
              }
            }
          
            conditional {
              if ($speaker != null) {
                var.update $speaker_refs {
                  value = $speaker_refs|push:$speaker
                }
              }
            }
          }
        }
      }
    }
  }

  response = {
    evidence_count           : $evidence_count
    contradict_count         : $contradict_count
    independent_source_count : $source_ids|unique|count
    independent_speaker_count: $speaker_refs|unique|count
  }

  guid = "RESXp7P3NG99c4zjR7rfkxxiCnw"
}