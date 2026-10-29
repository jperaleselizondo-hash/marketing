// Table-based rate limiting (Redis rate limiting is not available on this Xano plan).
// One row per counted attempt in a bucket such as "login:email:<email>" or "login:ip:<ip>".
table login_attempts {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text bucket_key
    text? remote_ip?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "bucket_key"}, {name: "created_at", op: "desc"}]
    }
  ]

  guid = "BjH1DYawT9EWa3YVLC8xKevMwB4"
}