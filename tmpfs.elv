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
    var url = 'github.com/chlorm/elvish-tmpfs'
    var libDir = (path:clean (epm:metadata $url)['dst'])

    var startupDir = (path:home)'\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    if (not (os:is-dir $startupDir)) {
        os:makedirs $startupDir
    }

    var bat = '\clear-temp.bat'
    if (not (os:exists $startupDir$bat)) {
        os:copy $libDir$bat $startupDir
    }
}

fn -try [path]{
    if (not (os:is-dir $path)) {
        os:makedirs $path 2>&-
    }

    var stat = [&]
    if $platform:is-windows {
        # Require the batch file before returning as a valid tmp dir.
        -install-windows-bat
        set stat['blocks'] = 1
    } else {
        os:chmod 0700 $path
        set stat = (os:statfs $path)
        var type = $stat['type']
        if (not (or (==s $type 'tmpfs') (==s $type 'ramfs'))) {
            fail
        }
    }
    utils:test-writeable $path

    # HACK: This returns the stat output to avoid calling stat multiple times.
    put $stat
}

# Returns a writable tmpfs directory.
fn get-user [&by-size=$false]{
    try {
        var possibleDirs = [ ]
        if $platform:is-windows {
            set possibleDirs = [
                (get-env 'TEMP')
            ]
        } else {
            var uid = (os:uid)
            set possibleDirs = [
                $E:ROOT'/run/user/'$uid
                $E:ROOT'/dev/shm/'$uid
                $E:ROOT'/run/shm/'$uid
                $E:ROOT'/tmp/'$uid
                $E:ROOT'/var/tmp/'$uid
            ]
        }
        var possibleDirsStats = [&]
        for dir $possibleDirs {
            try {
                set possibleDirsStats[$dir] = (-try $dir)
            } except _ {
                continue
            }
        }
        # Prefer first (or first largest) dir
        var largest = 0
        var largest-dir = $nil
        var first = $nil
        for dir $possibleDirs {
            var blocks = 0
            try {
                set blocks = $possibleDirsStats[$dir]['blocks']
            } except _ { }
            if (eq $first $nil) {
                set first = $dir
            }
            if (> $blocks $largest) {
                set largest = $blocks
                set largest-dir = $dir
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
