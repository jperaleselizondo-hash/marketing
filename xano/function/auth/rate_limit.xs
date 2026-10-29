// Fixed-window rate limit backed by login_attempts.
// check_only=true verifies the bucket is under its limit without recording; otherwise one attempt is recorded.
// Rows older than one day in the bucket are purged opportunistically.
function "auth/rate_limit" {
  input {
    text bucket_key
    int max_attempts
    int window_seconds
    bool check_only?
  }

  stack {
    var $window_start {
      value = now
        |transform_timestamp:"-" ~ ($input.window_seconds|to_text) ~ " seconds"
    }
  
    db.query login_attempts {
      where = $db.login_attempts.bucket_key == $input.bucket_key && $db.login_attempts.created_at > $window_start
      return = {type: "count"}
    } as $recent
  
    precondition ($recent < $input.max_attempts) {
      error_type = "accessdenied"
      error = "RATE_LIMITED: Too many attempts. Try again later."
    }
  
    var $purge_before {
      value = now|transform_timestamp:"-1 day"
    }
  
    conditional {
      if ($input.check_only == false) {
        db.add login_attempts {
          data = {
            created_at: now
            bucket_key: $input.bucket_key
            remote_ip : $env.$remote_ip
          }
        }
      
        db.bulk.delete login_attempts {
          where = $db.login_attempts.bucket_key == $input.bucket_key && $db.login_attempts.created_at < $purge_before
        } as $purged
      }
    }
  }

  response = $recent + 1
  guid = "4pU_4qB7Y2UVId_jQ4ri97hIda4"
}