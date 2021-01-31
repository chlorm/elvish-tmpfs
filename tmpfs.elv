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


use path path_
use platform
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/utils


# Since Windows has no tmpfs and doesn't clear TEMP, we need to install
# a batch script to clear it at startup.
fn -install-windows-bat {
    use epm
    url = 'github.com/chlorm/elvish-user-tmpfs'
    libDir = (path_:clean (epm:metadata $url)['dst'])

    startupDir = (path:home)'\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    if (not (os:is-dir $startupDir)) {
        os:makedirs $startupDir
    }

    bat = '\clear-temp.bat'
    if (not (os:exists $startupDir$bat)) {
        os:copy $libDir$bat $startupDir
    }
}

fn -try [path]{
    if (not (os:is-dir $path)) {
        os:makedirs $path 2>&-
    }

    stat = [&]
    if $platform:is-windows {
        # Require the batch file before returning as a valid tmp dir.
        -install-windows-bat
        stat[blocks] = 1
    } else {
        os:chmod 0700 $path
        stat = (os:statfs $path)
        type = $stat[type]
        if (not (or (==s $type 'tmpfs') (==s $type 'ramfs'))) {
            fail
        }
    }
    utils:test-writeable $path

    # HACK: This returns the stat output to avoid calling stat multiple times.
    put $stat
}

# Returns a writable tmpfs directory.
fn get-user-tmpfs [&by-size=$false]{
    try {
        uid = $nil
        try {
            uid = (os:uid)
        } except _ { }
        if (eq $uid $nil) {
            fail 'Could not determine UID'
        }

        possibleDirs = [ ]
        if $platform:is-windows {
            possibleDirs = [
                (get-env TEMP)
            ]
        } else {
            possibleDirs = [
                $E:ROOT'/run/user/'$uid
                $E:ROOT'/dev/shm/'$uid
                $E:ROOT'/run/shm/'$uid
                $E:ROOT'/tmp/'$uid
                $E:ROOT'/var/tmp/'$uid
            ]
        }
        possibleDirsStats = [&]
        for dir $possibleDirs {
            try {
                possibleDirsStats[$dir] = (-try $dir)
            } except _ {
                continue
            }
        }
        # Prefer first (or first largest) dir
        largest = 0
        largest-dir = $nil
        first = $nil
        for dir $possibleDirs {
            blocks = 0
            try {
                blocks = $possibleDirsStats[$dir][blocks]
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
