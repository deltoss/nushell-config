def "twin format" [filename?] {
  use std/clip
  use std-rfc/str

  let input = $in

  let twin_content = (
    match $filename {
      null => $input
      _ => { open --raw $filename }
    }
  )

  {
    Authorization: $'Bearer ($env.OPENROUTER_API_KEY)'
  }
  | kv set headers

  $"
    Rewrite the following auto-generated changelog so it's more natural. For example,
    change things like 'rgwood created [Bump dependencies...' to 'rgwood [bumped dependencies...'.
    Keep the inline links. Make sure to keep ALL original URLs! Keep the list structure with
    the top level list item being the contributor, and the sublist with one PR as each list item.

    Move the 'nushell' repo so that it is the first section (## second level heading).
        
    Always move dependabot contributor to the last position in each section. When returning the text,
    do not include any explaination of the change or the surrounding backticks around the result:

    ```
    ($twin_content)
    ```
  "
  | str unindent
  | kv set prompt

  {
    role: 'user'
    content: (kv drop prompt)
  }
  | kv set message

  {
    # model: 'deepseek/deepseek-chat-v3-0324'
    model: 'deepseek/deepseek-v4-flash'
    messages: [ (kv drop message) ]
  }
  | kv set body

  http post -ef -t application/json -H (kv drop headers) https://openrouter.ai/api/v1/chat/completions (kv drop body)
  | kv set rewrite

  kv drop rewrite
  | get body.choices.0.message.content
  | kv set rewrite_body

  kv drop rewrite_body
}
