# MSYS2 shells. Windows-only, imported conditionally from tools.nu.
# Takes precedence over the WSL `bash.exe` shim in System32.
#
# Can't be plain aliases: `C:\msys64\usr\bin` is deliberately kept off the Windows PATH
# (MSYS2 recommends this), so a bare `bash.exe` starts with no coreutils and any
# script calling grep/dirname/sed dies with "command not found".
#
# `-l` makes it a login shell so /etc/profile builds a real MSYS2 PATH
# (/usr/bin plus /$MSYSTEM/bin), and CHERE_INVOKING=1 keeps the current directory
# instead of cd'ing to $HOME. This is what msys2_shell.cmd does.
#
# MSYS2_PATH_TYPE=inherit appends the Windows PATH after the MSYS2 one, so git,
# dotnet, mise-managed cmake etc. stay reachable. /etc/profile defaults to
# `minimal`, which drops everything except System32.
const msys2_bin = "C:/msys64/usr/bin"
const msys2_env = { CHERE_INVOKING: "1", MSYS2_PATH_TYPE: "inherit" }

export def --wrapped bash [...args] {
  let exe = $"($msys2_bin)/bash.exe"
  with-env $msys2_env { ^$exe -l ...$args }
}

export def --wrapped sh [...args] {
  let exe = $"($msys2_bin)/sh.exe"
  with-env $msys2_env { ^$exe -l ...$args }
}