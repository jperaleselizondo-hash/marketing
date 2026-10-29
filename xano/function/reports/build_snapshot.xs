// Assemble the immutable Research Report snapshot (schema 1.0) from approved project data only.
// Approved insights are split into evidenced IVOC findings, opportunities and hypotheses (never presented as findings).
// Every evidence entry keeps observation -> excerpt -> source ids. Counts describe the collected sample, not the market.
function "reports/build_snapshot" {
  input {
    int project_id
  }

  stack {
    db.get research_projects {
      field_name = "id"
      field_value = $input.project_id
    } as $project
  
    db.get methodology_versions {
      field_name = "id"
      field_value = $project.methodology_version_id
    } as $methodology
  
    db.get products {
      field_name = "id"
      field_value = $project.product_id
    } as $product
  
    db.query research_segments {
      where = $db.research_segments.research_project_id == $input.project_id
      sort = {id: "asc"}
      return = {type: "list"}
    } as $segments
  
    db.query product_capabilities {
      where = $db.product_capabilities.research_project_id == $input.project_id
      sort = {id: "asc"}
      return = {type: "list"}
    } as $capabilities
  
    db.query product_benefits {
      where = $db.product_benefits.research_project_id == $input.project_id && $db.product_benefits.review_status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $benefits
  
    db.query capability_benefit_links {
      where = $db.capability_benefit_links.research_project_id == $input.project_id && $db.capability_benefit_links.review_status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $cap_benefit_links
  
    db.query product_proofs {
      where = $db.product_proofs.research_project_id == $input.project_id && $db.product_proofs.review_status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $proofs
  
    db.query benefit_desire_links {
      where = $db.benefit_desire_links.research_project_id == $input.project_id && $db.benefit_desire_links.review_status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $benefit_desire_links
  
    db.query research_assessments {
      where = $db.research_assessments.research_project_id == $input.project_id && $db.research_assessments.review_status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $assessments
  
    db.query competitors {
      where = $db.competitors.research_project_id == $input.project_id && $db.competitors.review_status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $competitors
  
    db.query competitor_observations {
      where = $db.competitor_observations.research_project_id == $input.project_id && $db.competitor_observations.review_status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $competitor_observations
  
    db.query research_insights {
      where = $db.research_insights.research_project_id == $input.project_id && $db.research_insights.status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $insights
  
    db.query insight_support {
      where = $db.insight_support.research_project_id == $input.project_id && $db.insight_support.review_status == "approved"
      sort = {id: "asc"}
      return = {type: "list"}
    } as $support
  
    db.query insight_rankings {
      where = $db.insight_rankings.research_project_id == $input.project_id && $db.insight_rankings.review_status == "approved"
      sort = {priority_rank: "asc"}
      return = {type: "list"}
    } as $rankings
  
    db.query research_observations {
      where = $db.research_observations.research_project_id == $input.project_id
      return = {type: "list"}
    } as $observations
  
    db.query source_excerpts {
      where = $db.source_excerpts.research_project_id == $input.project_id
      return = {type: "list"}
    } as $excerpts
  
    db.query research_sources {
      where = $db.research_sources.research_project_id == $input.project_id
      return = {type: "list"}
    } as $sources
  
    var $obs_by_id {
      value = $observations|index_by:"id"
    }
  
    var $exc_by_id {
      value = $excerpts|index_by:"id"
    }
  
    var $src_by_id {
      value = $sources|index_by:"id"
    }
  
    var $support_by_insight {
      value = $support|index_by:"insight_id"
    }
  
    var $ivoc_findings {
      value = []
    }
  
    var $opportunities {
      value = []
    }
  
    var $hypotheses {
      value = []
    }
  
    var $source_ids {
      value = []
    }
  
    var $withheld_count {
      value = 0
    }
  
    var $sup_rows {
      value = []
    }
  
    var $supporting {
      value = []
    }
  
    var $contradicting {
      value = []
    }
  
    var $obs {
      value = null
    }
  
    var $exc {
      value = null
    }
  
    var $src {
      value = null
    }
  
    var $finding {
      value = null
    }
  
    foreach ($insights) {
      each as $insight {
        var.update $sup_rows {
          value = ($support_by_insight|get:($insight.id|to_text)) ?? []
        }
      
        var.update $supporting {
          value = []
        }
      
        var.update $contradicting {
          value = []
        }
      
        foreach ($sup_rows) {
          each as $sr {
            var.update $obs {
              value = (($obs_by_id|get:($sr.observation_id|to_text)) ?? [])|first
            }
          
            var.update $exc {
              value = null
            }
          
            var.update $src {
              value = null
            }
          
            conditional {
              if (($obs|get:"source_excerpt_id") != null) {
                var.update $exc {
                  value = (($exc_by_id|get:($obs.source_excerpt_id|to_text)) ?? [])|first
                }
              }
            }
          
            conditional {
              if ($exc != null) {
                var.update $src {
                  value = (($src_by_id|get:($exc.source_id|to_text)) ?? [])|first
                }
              
                var.update $source_ids {
                  value = $source_ids|push:$exc.source_id
                }
              }
            }
          
            conditional {
              if ($obs != null) {
                function.run "reports/evidence_item" {
                  input = {
                    observation: $obs
                    excerpt    : $exc
                    source     : $src
                    stance     : $sr.stance
                  }
                } as $item
              
                conditional {
                  if (($item|get:"text_withheld_reason") != null) {
                    var.update $withheld_count {
                      value = $withheld_count + 1
                    }
                  }
                }
              
                conditional {
                  if ($sr.stance == "support") {
                    var.update $supporting {
                      value = $supporting|push:$item
                    }
                  }
                
                  else {
                    var.update $contradicting {
                      value = $contradicting|push:$item
                    }
                  }
                }
              }
            }
          }
        }
      
        function.run "synthesis/evidence_counts" {
          input = {insight_id: $insight.id}
        } as $counts
      
        var.update $finding {
          value = {
            insight_id         : $insight.id
            research_segment_id: $insight.research_segment_id
            insight_kind       : $insight.insight_kind
            ivoc_category      : $insight.ivoc_category
            statement          : $insight.statement
            evidence_basis     : $insight.evidence_basis
            confidence         : $insight.confidence
            origin             : $insight.origin
            counts             : $counts
            counts_note        : "Counts are approved observations in the collected sample, not market prevalence."
            supporting         : $supporting
            contradicting      : $contradicting
          }
        }
      
        conditional {
          if ($insight.evidence_basis == "hypothesis") {
            var.update $hypotheses {
              value = $hypotheses|push:$finding
            }
          }
        
          elseif ($insight.insight_kind == "opportunity") {
            var.update $opportunities {
              value = $opportunities|push:$finding
            }
          }
        
          else {
            var.update $ivoc_findings {
              value = $ivoc_findings|push:$finding
            }
          }
        }
      }
    }
  
    foreach ($proofs) {
      each as $proof {
        conditional {
          if (($proof|get:"source_excerpt_id") != null) {
            var.update $exc {
              value = (($exc_by_id|get:($proof.source_excerpt_id|to_text)) ?? [])|first
            }
          
            conditional {
              if ($exc != null) {
                var.update $source_ids {
                  value = $source_ids|push:$exc.source_id
                }
              }
            }
          }
        }
      }
    }
  
    foreach ($competitor_observations) {
      each as $co {
        conditional {
          if (($co|get:"source_excerpt_id") != null) {
            var.update $exc {
              value = (($exc_by_id|get:($co.source_excerpt_id|to_text)) ?? [])|first
            }
          
            conditional {
              if ($exc != null) {
                var.update $source_ids {
                  value = $source_ids|push:$exc.source_id
                }
              }
            }
          }
        }
      }
    }
  
    var $unique_source_ids {
      value = ($source_ids|unique)|sort:"":"number":true
    }
  
    var $manifest {
      value = []
    }
  
    var $manifest_text {
      value = ""
    }
  
    foreach ($unique_source_ids) {
      each as $sid {
        var.update $src {
          value = (($src_by_id|get:($sid|to_text)) ?? [])|first
        }
      
        var.update $manifest {
          value = $manifest
            |push:{source_id: $src.id, title: $src.title, source_kind: $src.source_kind, canonical_url: $src.canonical_url, publisher: $src.publisher, captured_at: $src.captured_at, language_code: $src.language_code, content_hash: $src.content_hash, usage_rights: $src.usage_rights, personal_data_class: $src.personal_data_class, processing_basis_status: $src.processing_basis_status}
        }
      
        var.update $manifest_text {
          value = $manifest_text ~ ($src.id|to_text) ~ ":" ~ ($src.content_hash ?? "none") ~ "|"
        }
      }
    }
  
    var $competitor_obs_by_competitor {
      value = $competitor_observations|index_by:"competitor_id"
    }
  
    var $competitor_matrix {
      value = []
    }
  
    foreach ($competitors) {
      each as $comp {
        var.update $competitor_matrix {
          value = $competitor_matrix
            |push:{competitor_id: $comp.id, name: $comp.name, website: $comp.website, alternative_type: $comp.alternative_type, positioning_summary: $comp.positioning_summary, observations: ($competitor_obs_by_competitor|get:($comp.id|to_text)) ?? []}
        }
      }
    }
  
    db.query source_excerpts {
      where = $db.source_excerpts.research_project_id == $input.project_id && $db.source_excerpts.verification_status != "verified"
      return = {type: "count"}
    } as $unverified_excerpts
  
    db.query research_observations {
      where = $db.research_observations.research_project_id == $input.project_id && $db.research_observations.review_status != "approved"
      return = {type: "count"}
    } as $unapproved_observations
  
    db.query research_insights {
      where = $db.research_insights.research_project_id == $input.project_id && $db.research_insights.status != "approved"
      return = {type: "count"}
    } as $unapproved_insights
  
    var $blocking {
      value = []
    }
  
    conditional {
      if (($segments|count) == 0) {
        var.update $blocking {
          value = $blocking|push:"NO_SEGMENTS"
        }
      }
    }
  
    var $warnings {
      value = []
    }
  
    conditional {
      if (($ivoc_findings|count) == 0) {
        var.update $warnings {
          value = $warnings
            |push:"NO_EVIDENCED_FINDINGS: all conclusions in this report are hypotheses"
        }
      }
    }
  
    conditional {
      if ((($manifest|filter:($$.content_hash == null))|count) > 0) {
        var.update $warnings {
          value = $warnings
            |push:"SOURCES_WITHOUT_STORED_CONTENT: some cited sources have no content hash; their excerpts are hashed individually"
        }
      }
    }
  
    var $report {
      value = {
        schema_version       : "1.0"
        generated_at         : now
        based_on_revision    : $project.content_revision
        organization_id      : $project.organization_id
        project              : {id: $project.id, title: $project.title, objective: $project.objective, scope: $project.scope, target_geography: $project.target_geography, target_locale: $project.target_locale}
        methodology          : {id: $methodology.id, key: $methodology.key, version: $methodology.version, title: $methodology.title}
        product              : {id: $product.id, name: $product.name, description: $product.description, lifecycle_status: $product.lifecycle_status}
        audience_segments    : $segments
        product_matrix       : {capabilities: $capabilities, benefits: $benefits, capability_benefit_links: $cap_benefit_links, proofs: $proofs, benefit_desire_links: $benefit_desire_links}
        assessments          : $assessments
        competitive_landscape: $competitor_matrix
        ivoc_findings        : $ivoc_findings
        desire_prioritization: $rankings
        opportunities        : $opportunities
        hypotheses_and_gaps  : $hypotheses
        limitations          : {
          unverified_excerpts    : $unverified_excerpts
          unapproved_observations: $unapproved_observations
          unapproved_insights    : $unapproved_insights
          withheld_texts         : $withheld_count
          note                   : "Scores and counts are reviewer estimates over the collected sample. They are not statistical estimates of market prevalence."
        }
        warnings             : $warnings
        blocking_issues      : $blocking
        source_manifest      : {sources: $manifest, manifest_hash: ($manifest_text|sha256)}
      }
    }
  
    var $md {
      value = "# Research Report: " ~ $project.title ~ "\n\n" ~ "Objective: " ~ $project.objective ~ "\n\n" ~ "Methodology: " ~ $methodology.key ~ " v" ~ $methodology.version ~ " | Revision " ~ ($project.content_revision|to_text) ~ "\n\n## Evidenced IVOC findings\n"
    }
  
    foreach ($ivoc_findings) {
      each as $f {
        var.update $md {
          value = $md ~ "- [" ~ ($f.ivoc_category ?? "theme") ~ "] " ~ $f.statement ~ " (supporting: " ~ ($f.counts.evidence_count|to_text) ~ ", contradicting: " ~ ($f.counts.contradict_count|to_text) ~ ", independent sources: " ~ ($f.counts.independent_source_count|to_text) ~ ")\n"
        }
      }
    }
  
    var.update $md {
      value = $md ~ "\n## Hypotheses and gaps (not established findings)\n"
    }
  
    foreach ($hypotheses) {
      each as $h {
        var.update $md {
          value = $md ~ "- " ~ $h.statement ~ "\n"
        }
      }
    }
  
    var.update $md {
      value = $md ~ "\n## Limitations\n- " ~ ($withheld_count|to_text) ~ " evidence texts withheld under rights/privacy rules\n- Counts describe the collected sample, not the market.\n\n## Sources\n"
    }
  
    foreach ($manifest) {
      each as $m {
        var.update $md {
          value = $md ~ "- [S" ~ ($m.source_id|to_text) ~ "] " ~ $m.title ~ " (" ~ $m.source_kind ~ ")\n"
        }
      }
    }
  }

  response = {
    report_json    : $report
    report_markdown: $md
    source_ids     : $unique_source_ids
    manifest_hash  : $manifest_text|sha256
    blocking_issues: $blocking
  }

  guid = "vgG9k4VzUJ9qJNK5_UzaraZdMWI"
}