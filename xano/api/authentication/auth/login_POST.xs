// Login and retrieve an authentication token. Rate limited per IP and per email; suspended accounts cannot log in.
query "auth/login" verb=POST {
  api_group = "Authentication"

  input {
    email email filters=trim|lower
    text password
  }

  stack {
    function.run "auth/rate_limit" {
      input = {
        bucket_key    : "login:ip:" ~ $env.$remote_ip
        max_attempts  : 30
        window_seconds: 900
      }
    } as $ip_attempts
  
    function.run "auth/rate_limit" {
      input = {
        bucket_key    : "login:email:" ~ $input.email
        max_attempts  : 5
        window_seconds: 900
        check_only    : true
      }
    } as $email_attempts
  
    db.get user {
      field_name = "email"
      field_value = $input.email
      output = ["id", "password", "status"]
    } as $user
  
    var $pass_result {
      value = false
    }
  
    conditional {
      if ($user != null) {
        security.check_password {
          text_password = $input.password
          hash_password = $user.password
        } as $checked
      
        var.update $pass_result {
          value = $checked
        }
      }
    }
  
    conditional {
      if ($pass_result == false) {
        function.run "auth/rate_limit" {
          input = {
            bucket_key    : "login:email:" ~ $input.email
            max_attempts  : 1000000
            window_seconds: 900
          }
        } as $recorded
      }
    }
  
    precondition ($pass_result && $user.status != "suspended") {
      error_type = "accessdenied"
      error = "Invalid Credentials."
    }
  
    db.edit user {
      field_name = "id"
      field_value = $user.id
      data = {last_login_at: now}
    }
  
    security.create_auth_token {
      table = "user"
      extras = {}
      expiration = 28800
      id = $user.id
    } as $authToken
  }

  response = {authToken: $authToken}
  guid = "T2Np9Vk2yv4s1mosWWvN9vPQmYA"
}