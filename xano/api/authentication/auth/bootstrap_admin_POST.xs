// One-time owner bootstrap. Creates the first platform administrator only while none exists and only
// with the secret held in the workspace environment variable MKTENG_BOOTSTRAP_SECRET.
query "auth/bootstrap-admin" verb=POST {
  api_group = "Authentication"

  input {
    text bootstrap_secret
    text name filters=trim
    email email filters=trim|lower
    text password
  }

  stack {
    function.run "auth/rate_limit" {
      input = {
        bucket_key    : "bootstrap:ip:" ~ $env.$remote_ip
        max_attempts  : 5
        window_seconds: 3600
      }
    } as $attempts
  
    var $secret {
      value = $env.MKTENG_BOOTSTRAP_SECRET ?? ""
    }
  
    precondition (($secret|strlen) >= 32 && $input.bootstrap_secret == $secret) {
      error_type = "accessdenied"
      error = "BOOTSTRAP_DISABLED: Bootstrap is not available"
    }
  
    db.query user {
      where = $db.user.is_platform_admin == true
      return = {type: "count"}
    } as $admin_count
  
    precondition ($admin_count == 0) {
      error_type = "accessdenied"
      error = "BOOTSTRAP_DISABLED: Bootstrap is not available"
    }
  
    precondition (($input.password|strlen) >= 12 && ($input.name|strlen) > 0) {
      error_type = "inputerror"
      error = "VALIDATION: name and a password of at least 12 characters are required"
    }
  
    db.get user {
      field_name = "email"
      field_value = $input.email
    } as $existing
  
    precondition ($existing == null) {
      error_type = "inputerror"
      error = "ACCOUNT_EXISTS: An account with this email already exists"
    }
  
    db.add user {
      data = {
        created_at       : now
        name             : $input.name
        email            : $input.email
        password         : $input.password
        status           : "active"
        is_platform_admin: true
      }
    } as $user
  
    function.run "audit/log_event" {
      input = {
        actor_id   : $user.id
        entity_type: "user"
        entity_id  : $user.id
        action     : "bootstrap_platform_admin"
      }
    }
  
    security.create_auth_token {
      table = "user"
      extras = {}
      expiration = 28800
      id = $user.id
    } as $authToken
  }

  response = {authToken: $authToken}
  guid = "gi9JBoOO_lb1UxAUmOu5kP_b16s"
}