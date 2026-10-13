# Cache a value lazily, with a 15-minute idle timeout.
# stor is process-local memory. Do not export it to disk if it holds secrets.
export def cache-value [key: string fetch: closure] {
  let db = stor open
  $db | query db "CREATE TABLE IF NOT EXISTS cache (key TEXT PRIMARY KEY, value TEXT NOT NULL)" | ignore
  let entry = ($db
    | query db "SELECT value FROM cache WHERE key = :key" --params {key: $key}
    | get --optional 0.value | default "null" | from nuon)
  let expiry = $entry | get --optional expires_at
  let value = if ($expiry | describe) == "datetime" and ($expiry > (date now)) {
    $entry.value
  } else {
    do $fetch
  }

  # Reset the idle timeout on every use. NUON preserves the value types.
  $db | query db (
    "INSERT INTO cache (key, value) VALUES (:key, :value)"
    + " ON CONFLICT(key) DO UPDATE SET value = excluded.value"
  ) --params {
    key: $key
    value: ({value: $value, expires_at: ((date now) + 15min)} | to nuon)
  } | ignore
  $value
}