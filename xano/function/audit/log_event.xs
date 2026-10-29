// Append a review/audit event. review_events is append-only: no endpoint updates or deletes it.
function "audit/log_event" {
  input {
    int? organization_id?
    int? research_project_id?
    int actor_id
    text entity_type
    int entity_id
    text action
    text? gate_code?
    text? from_status?
    text? to_status?
    text? reason?
    text? before_hash?
    text? after_hash?
    json? details?
  }

  stack {
    db.add review_events {
      data = {
        created_at         : now
        organization_id    : $input.organization_id
        research_project_id: $input.research_project_id
        actor_id           : $input.actor_id
        entity_type        : $input.entity_type
        entity_id          : $input.entity_id
        action             : $input.action
        gate_code          : $input.gate_code
        from_status        : $input.from_status
        to_status          : $input.to_status
        reason             : $input.reason
        before_hash        : $input.before_hash
        after_hash         : $input.after_hash
        details            : $input.details
      }
    } as $event
  }

  response = $event
  guid = "Dqz4EVflmXojsBtPZ3DAV5zm944"
}