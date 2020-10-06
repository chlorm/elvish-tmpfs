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


use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-user-tmpfs/tmpfs
use github.com/chlorm/elvish-xdg/xdg


fn main {
    # Make sure XDG_RUNTIME_DIR is configured.
    local:run = (xdg:get-dir XDG_RUNTIME_DIR)
    if (not (==s (get-env XDG_RUNTIME_DIR) $run)) {
        set-env XDG_RUNTIME_DIR $run
    }

    local:mount-cache = $false
    try {
        mount-cache = (bool ?(get-env MOUNT_XDG_CACHE_HOME_TO_TMPFS >/dev/null))
    } except _ {
        # Ignore
    }
    if (eq $true $mount-cache) {
        local:xdg-cache-home = (xdg:get-dir XDG_CACHE_HOME)
        local:tmp = (tmpfs:get-user-tmpfs &by-size=$true)
        if (!=s $tmp $xdg-cache-home) {
            # FIXME: test for directory first
            os:symlink $tmp $xdg-cache-home
        }
    }
}

main

