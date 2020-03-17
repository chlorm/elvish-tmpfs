

use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-user-tmpfs/tmpfs
use github.com/chlorm/elvish-xdg/xdg


fn main {
  # Make sure XDG_RUNTIME_DIR is configured.
  local:capture = (xdg:get-dir XDG_RUNTIME_DIR)

  local:mount-cache = $false
  try {
    mount-cache = (get-env MOUNT_XDG_CACHE_HOME_TO_TMPFS)
  } except _ {
    # Ignore
  }
  if (eq $true $mount-cache) {
    local:xdg-cache-home = (xdg:get-dir XDG_CACHE_HOME)
    local:tmp = (tmpfs:get-user-tmpfs)
    if (!=s $tmp $xdg-cache-home) {
      # FIXME: test for directory first
      os:symlink $tmp $xdg-cache-home
    }
  }
}

main
