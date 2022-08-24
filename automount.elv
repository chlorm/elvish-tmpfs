# Copyright (c) 2018, 2020, Cody Opel <cwopel@chlorm.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use github.com/chlorm/elvish-stl/env
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/platform
use github.com/chlorm/elvish-tmpfs/tmpfs
use github.com/chlorm/elvish-xdg/xdg-dirs


fn main {
    # Make sure XDG_RUNTIME_DIR is configured.
    if (eq (env:get-value-or-nil $xdg-dirs:XDG-RUNTIME-DIR) $nil) {
        var run = (xdg-dirs:runtime-dir)
        env:set $xdg-dirs:XDG-RUNTIME-DIR $run
    }

    var mountCache = $false
    if (not (or $platform:is-darwin $platform:is-windows)) {
        try {
            set mountCache = (env:has 'MOUNT_XDG_CACHE_HOME_TO_TMPFS')
        } catch _ { }
    }
    if $mountCache {
        var xdgCacheHome = (xdg-dirs:cache-home)
        var tmpfs = (tmpfs:get-user &by-size=$true)
        if (!=s $tmpfs $xdgCacheHome) {
            # FIXME: test for directory first
            os:symlink $tmpfs $xdgCacheHome
        }
    }
}

main

