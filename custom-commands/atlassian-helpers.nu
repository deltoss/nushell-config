use ../tools/1password.nu [op-secret]
use ./cache-helpers.nu [cache-value]

# Every Atlassian credential lives on the same 1Password item; only the field differs
const ITEM = "op://Work/Atlassian - Work"

# Explicit environment overrides take priority over the shared memory cache.
def env-or-cached [env_key: string fetch: closure] {
  let override = $env | get --optional $env_key
  if ($override | is-not-empty) {
    return $override
  }
  cache-value $env_key $fetch
}

# Atlassian account username (email), shared by the Jira and Bitbucket APIs
def username [] {
  op-secret ATLASSIANUSERNAME $"($ITEM)/username"
}

# Atlassian site base URL without a trailing slash, e.g. https://<site>.atlassian.net
export def base-url [] {
  env-or-cached JIRABASEURL { op-secret JIRABASEURL $"($ITEM)/Base URL" }
    | str trim --right --char '/'
}

# Raw Jira API key, from 1Password (or $env.JIRAAPIKEY when set)
export def jira-api-key [] {
  op-secret JIRAAPIKEY $"($ITEM)/Scripting - Jira"
}

# Raw Bitbucket API key, from 1Password (or $env.BITBUCKETAPIKEY when set)
export def bitbucket-api-key [] {
  op-secret BITBUCKETAPIKEY $"($ITEM)/Scripting - BitBucket"
}

# Basic-auth token for the Jira API, built from the API key
# (or $env.JIRABASE64AUTHTOKEN when set as a prebuilt override)
export def jira-basic-token [] {
  env-or-cached JIRABASE64AUTHTOKEN { basic-token (jira-api-key) }
}

# Get the authenticated Jira account
export def jira-account [] {
  http get --headers {
    accept: application/json
    authorization: $"Basic (jira-basic-token)"
  } $"(base-url)/rest/api/3/myself"
}

# Get the authenticated Jira account ID, rejecting missing or unknown IDs.
export def jira-account-id [] {
  let account_id = jira-account | get accountId | str trim
  if ($account_id | is-empty) or $account_id == "unknown" {
    error make {msg: "Jira did not return a valid account ID"}
  }
  $account_id
}

# Basic-auth token for the Bitbucket API, built from the API key
# (or $env.BITBUCKETBASE64AUTHTOKEN when set as a prebuilt override)
export def bitbucket-basic-token [] {
  $env | get --optional BITBUCKETBASE64AUTHTOKEN | default --empty { basic-token (bitbucket-api-key) }
}

# HTTP Basic auth credentials for the Atlassian APIs: base64 of username:apikey
def basic-token [api_key: string] {
  $"(username):($api_key)" | encode base64
}