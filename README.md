# elvish-user-tmpfs

###### An [Elvish](https://elv.sh) module for finding a writable tmpfs.

```elvish
epm:install github.com/chlorm/elvish-user-tmpfs
use github.com/chlorm/elvish-user-tmpfs/tmpfs
# Optional
use github.com/chlorm/elvish-user-tmpfs/tmpfs-automount
```

#### WARNING:

On Windows this unconditionally installs a batch script to wipe %TEMP% on startup.
