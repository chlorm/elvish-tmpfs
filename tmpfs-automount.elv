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


use platform
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-user-tmpfs/tmpfs
use github.com/chlorm/elvish-xdg/xdg


fn main {
    # Make sure XDG_RUNTIME_DIR is configured.
    var run = (xdg:get-dir XDG_RUNTIME_DIR)
    if (not (==s (get-env XDG_RUNTIME_DIR) $run)) {
        set-env XDG_RUNTIME_DIR $run
    }

    var mountCache = $false
    try {
        set mountCache = (bool ?(get-env MOUNT_XDG_CACHE_HOME_TO_TMPFS >$os:NULL))
    } except _ {
        # Ignore
    }
    if (eq $mountCache $true) {
        if $platform:is-windows {
            return
        }
        var xdgCacheHome = (xdg:get-dir XDG_CACHE_HOME)
        var tmpfs = (tmpfs:get-user-tmpfs &by-size=$true)
        if (!=s $tmpfs $xdgCacheHome) {
            # FIXME: test for directory first
            os:symlink $tmpfs $xdgCacheHome
        }
    }
}

main

