// Single entry point for review decisions on research items: submit, approve, reject, reopen.
// Dispatches to the per-entity review/<table> function, which enforces scope, role, state and integrity rules.
query reviews verb=POST {
  api_group = "workflow"
  auth = "user"

  input {
    enum entity_type {
      values = [
        "research_sources"
        "research_observations"
        "product_benefits"
        "capability_benefit_links"
        "product_proofs"
        "competitors"
        "competitor_observations"
        "insight_support"
        "insight_rankings"
        "benefit_desire_links"
        "research_assessments"
        "research_insights"
      ]
    }
  
    int entity_id
    enum decision {
      values = ["submit", "approve", "reject", "reopen"]
    }
  
    text? reason?
  }

  stack {
    var $result {
      value = null
    }
  
    switch ($input.entity_type) {
      case ("research_sources") {
        function.run "review/research_sources" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("research_observations") {
        function.run "review/research_observations" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("product_benefits") {
        function.run "review/product_benefits" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("capability_benefit_links") {
        function.run "review/capability_benefit_links" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("product_proofs") {
        function.run "review/product_proofs" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("competitors") {
        function.run "review/competitors" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("competitor_observations") {
        function.run "review/competitor_observations" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("insight_support") {
        function.run "review/insight_support" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("insight_rankings") {
        function.run "review/insight_rankings" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("benefit_desire_links") {
        function.run "review/benefit_desire_links" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("research_assessments") {
        function.run "review/research_assessments" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      case ("research_insights") {
        function.run "review/research_insights" {
          input = {
            user_id  : $auth.id
            entity_id: $input.entity_id
            decision : $input.decision
            reason   : $input.reason
          }
        } as $item
      
        var.update $result {
          value = $item
        }
      } break
    
      default {
        precondition ($input.entity_type == "") {
          error_type = "inputerror"
          error = "VALIDATION: Unsupported entity_type"
        }
      }
    }
  }

  response = $result
  guid = "CX6jN5kBmloRMQSbFD_Xy8nJKu0"
}