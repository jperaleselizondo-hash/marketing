// Hash of a report's JSON exactly as stored. Postgres jsonb reorders keys, so hashes are always computed
// from the stored value read back, never from the in-memory object used to create it.
function "reports/report_hash" {
  input {
    int report_id
  }

  stack {
    db.get research_reports {
      field_name = "id"
      field_value = $input.report_id
    } as $report
  
    var $hash {
      value = ($report.report_json|json_encode)|sha256
    }
  }

  response = $hash
  guid = "ggSJKvO7RPPapLSZBaupJCKsf8E"
}