query "methodology-versions" verb=GET {
  api_group = "catalog"
  auth = "user"

  input {
    enum? status? {
      values = ["draft", "published", "retired"]
    }
  }

  stack {
    db.query methodology_versions {
      where = $db.methodology_versions.status ==? $input.status
      sort = {key: "asc"}
      return = {type: "list"}
    } as $versions
  }

  response = $versions
  guid = "SHIcsGWusGIIfSS7QKRYxOwy38Y"
}