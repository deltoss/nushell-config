plugin add (if $nu.os-info.name == "windows" {
  $env.USERPROFILE + "/.cargo/bin/nu_plugin_formats.exe"
} else {
  $env.HOME + "/.cargo/bin/nu_plugin_formats"
})
plugin use formats