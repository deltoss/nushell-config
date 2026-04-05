export def emit-user-var [name: string, value: string = ""] {
  let encoded_value = $value | encode base64
  print -n $"\u{1b}]1337;SetUserVar=($name)=($encoded_value)\u{07}"
}