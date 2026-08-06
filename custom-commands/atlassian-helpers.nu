use ../tools/1password.nu [op-secret]

# Every Atlassian credential lives on the same 1Password item; only the field differs
const ITEM = "op://Work/Atlassian - Work"

# Atlassian account username (email), shared by the Jira and Bitbucket APIs
def username [] {
  op-secret ATLASSIANUSERNAME $"($ITEM)/username"
}

# Atlassian site base URL, e.g. https://<site>.atlassian.net
export def base-url [] {
  op-secret JIRABASEURL $"($ITEM)/Base URL"
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
  $env | get --optional JIRABASE64AUTHTOKEN | default --empty { basic-token (jira-api-key) }
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