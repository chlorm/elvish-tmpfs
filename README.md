# elvish-tmpfs

###### An [Elvish](https://elv.sh) module for finding a writable tmpfs.

```elvish
epm:install github.com/chlorm/elvish-tmpfs
use github.com/chlorm/elvish-tmpfs/tmpfs
# Optional
use github.com/chlorm/elvish-tmpfs/automount
```

#### WARNING:

On Windows this unconditionally installs a batch script to wipe %TEMP% on startup.
