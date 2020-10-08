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
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/utils


# Since Windows has no tmpfs and doesn't clear TEMP, we need to install
# a batch script to clear it at startup.
fn -install-windows-bat {
    use epm
    local:url = 'github.com/chlorm/elvish-user-tmpfs'
    local:lib-dir = (path-clean (epm:metadata $url)['dst'])

    local:startup-dir = (path:home)'\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    if (not (os:is-dir $startup-dir)) {
        os:makedirs $startup-dir
    }

    local:bat = '\clear-temp.bat'
    if (not (os:exists $startup-dir$bat)) {
        cp -v $lib-dir$bat $startup-dir
    }
}

fn -try [path]{
    if (not (os:is-dir $path)) {
        os:makedirs $path 2>&-
    }

    local:s = [&]
    if $platform:is-windows {
        # Require the batch file before returning as a valid tmp dir.
        -install-windows-bat
        s[blocks] = 1
    } else {
        os:chmod 0700 $path
        s = (os:statfs $path)
        local:type = $s[type]
        if (not (or (==s $type 'tmpfs') (==s $type 'ramfs'))) {
            fail
        }
    }
    utils:test-writeable $path

    # HACK: This returns the stat output to avoid calling stat multiple times.
    put $s
}

# Returns a writable tmpfs directory.
fn get-user-tmpfs [&by-size=$false]{
    try {
        local:uid = $nil
        try {
            uid = (os:uid)
        } except _ { }
        if (eq $uid $nil) {
            fail 'Could not determine UID'
        }

        local:possible-dirs = [ ]
        if $platform:is-windows {
            possible-dirs = [
                (get-env TEMP)
            ]
        } else {
            possible-dirs = [
                $E:ROOT'/run/user/'$uid
                $E:ROOT'/dev/shm/'$uid
                $E:ROOT'/run/shm/'$uid
                $E:ROOT'/tmp/'$uid
                $E:ROOT'/var/tmp/'$uid
            ]
        }
        local:possible-dirs-stats = [&]
        for local:dir $possible-dirs {
            try {
                possible-dirs-stats[$dir]=(-try $dir)
            } except _ {
                continue
            }
        }
        # Prefer first (or first largest) dir
        local:largest = 0
        local:largest-dir = $nil
        local:first = $nil
        for local:dir $possible-dirs {
            local:blocks = 0
            try {
                blocks = $possible-dirs-stats[$dir][blocks]
            } except _ { }
            if (eq $first $nil) {
                first = $dir
            }
            if (> $blocks $largest) {
                largest = $blocks
                largest-dir = $dir
            }
        }

        if (or (eq $first $nil) (eq $largest-dir $nil)) {
            fail
        }

        if $by-size {
            put $largest-dir
        } else {
            put $first
        }
    } except {
        fail 'Could not find a writeable tmpfs'
    }
}
