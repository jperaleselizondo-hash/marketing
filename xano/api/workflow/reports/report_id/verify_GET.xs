// Integrity check of a report against its recorded hashes and the current state of its sources and excerpts.
query "reports/{report_id}/verify" verb=GET {
  api_group = "workflow"
  auth = "user"

  input {
    int report_id
  }

  stack {
    db.get research_reports {
      field_name = "id"
      field_value = $input.report_id
    } as $report
  
    precondition ($report != null) {
      error_type = "notfound"
      error = "NOT_FOUND: Report not found"
    }
  
    function.run "research/project_context" {
      input = {
        user_id   : $auth.id
        project_id: $report.research_project_id
        min_role  : "viewer"
      }
    } as $pc
  
    function.run "reports/report_hash" {
      input = {report_id: $report.id}
    } as $hash
  
    db.query research_report_sources {
      where = $db.research_report_sources.report_id == $report.id
      return = {type: "list"}
    } as $frozen_sources
  
    var $changed_sources {
      value = []
    }
  
    foreach ($frozen_sources) {
      each as $frozen {
        db.get research_sources {
          field_name = "id"
          field_value = $frozen.source_id
        } as $source
      
        conditional {
          if ($source == null || ($source|get:"content_hash") != ($frozen|get:"content_hash_at_approval")) {
            var.update $changed_sources {
              value = $changed_sources|push:$frozen.source_id
            }
          }
        }
      }
    }
  
    var $findings {
      value = (($report.report_json.ivoc_findings ?? [])|merge:($report.report_json.opportunities ?? []))|merge:($report.report_json.hypotheses_and_gaps ?? [])
    }
  
    var $changed_excerpts {
      value = []
    }
  
    var $evidence {
      value = []
    }
  
    foreach ($findings) {
      each as $finding {
        var.update $evidence {
          value = ($finding.supporting ?? [])|merge:($finding.contradicting ?? [])
        }
      
        foreach ($evidence) {
          each as $ev {
            conditional {
              if (($ev|get:"source_excerpt_id") != null) {
                db.get source_excerpts {
                  field_name = "id"
                  field_value = $ev.source_excerpt_id
                } as $excerpt
              
                conditional {
                  if ($excerpt == null || $excerpt.excerpt_hash != ($ev|get:"excerpt_hash") || $excerpt.redaction_status == "redacted") {
                    var.update $changed_excerpts {
                      value = $changed_excerpts|push:$ev.source_excerpt_id
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  response = {
    report_id            : $report.id
    version_no           : $report.version_no
    status               : $report.status
    is_current           : $pc.project.current_report_id == $report.id
    stale_against_project: $report.based_on_revision != $pc.project.content_revision
    json_hash_matches    : $hash == $report.report_json_hash
    approved_hash_matches: $report.approved_json_hash == null || $report.approved_json_hash == $hash
    changed_sources      : $changed_sources|unique
    changed_excerpts     : $changed_excerpts|unique
  }

  guid = "XEirdT5VN66Mr3OFCV0sB3X8CeY"
}