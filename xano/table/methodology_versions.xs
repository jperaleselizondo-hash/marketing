table methodology_versions {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp? updated_at?
    text key filters=trim|lower
    text version filters=trim
    text title filters=trim
    text? source_url?
    text? source_hash?
    date? reviewed_on?
    text? instructions_ref?
    enum status?=draft {
      values = ["draft", "published", "retired"]
    }
  
    int created_by {
      table = "user"
    }
  
    int? approved_by? {
      table = "user"
    }
  
    timestamp? approved_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree|unique"
      field: [{name: "key"}, {name: "version"}]
    }
  ]

  guid = "fMae8vwDEIVRC9K6dGkkRL245Z4"
}