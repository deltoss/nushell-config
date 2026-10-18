use ../tools/secretspec.nu [secret-value]

# The matching 1Password item and keyring-backed cache are declared in secretspec.toml.

# Atlassian account username (email), shared by the Jira and Bitbucket APIs
def username [] {
  secret-value ATLASSIANUSERNAME
}

# Atlassian site base URL without a trailing slash, e.g. https://<site>.atlassian.net
export def base-url [] {
  secret-value JIRABASEURL | str trim --right --char '/'
}

# Raw Jira API key, cached by SecretSpec (or $env.JIRAAPIKEY when set)
export def jira-api-key [] {
  secret-value JIRAAPIKEY
}

# Raw Bitbucket API key, cached by SecretSpec (or $env.BITBUCKETAPIKEY when set)
export def bitbucket-api-key [] {
  secret-value BITBUCKETAPIKEY
}

# Basic-auth token for the Jira API, built from the API key
# (or $env.JIRABASE64AUTHTOKEN when set as a prebuilt override)
export def jira-basic-token [] {
  $env | get --optional JIRABASE64AUTHTOKEN | default --empty { basic-token (jira-api-key) }
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