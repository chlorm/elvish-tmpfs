
use github.com/chlorm/elvish-user-tmpfs/tmpfs

fn main {
  local:tmpdir = (tmpfs:get-user-tmpfs)

  local:mount-cache = $false
  try {
    # FIXME: We use an environment variable because un declared variable
    #        errors fall through try/except.
    mount-cache = (get-env MOUNT_XDG_CACHE_HOME_TO_TMPFS)
  } except {
    mount-cache = $false
  }
  if (eq $mount-cache $true) {
    mount-xdg-cache-on-tmpfs $tmpdir
  }

  #mount-xdg-cache-on-tmpfs $tmpdir
}

main
