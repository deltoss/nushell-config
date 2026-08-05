use ../tools/1password.nu [op-secret]

# Atlassian account username (email), shared by the Jira and Bitbucket APIs
def username [] {
  op-secret ATLASSIANUSERNAME "op://Work/Atlassian - Work/username"
}

# Build an HTTP Basic auth token for an Atlassian API key stored in
# 1Password: base64 of username:apikey. An already-set env var takes
# priority as a prebuilt-token override
export def basic-token [
  env_key: string # Environment variable holding a prebuilt base64 token
  api_key_ref: string # 1Password reference to the API key, e.g. op://Vault/Item/Field
] {
  let override = $env | get --optional $env_key
  if ($override | is-not-empty) {
    return $override
  }

  let api_key = ^op read $api_key_ref | str trim
  $"(username):($api_key)" | encode base64
}