# Copyright (c) 2018, 2020, 2022, Cody Opel <cwopel@chlorm.net>
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
use github.com/chlorm/elvish-stl/io
use github.com/chlorm/elvish-stl/list
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/platform
use github.com/chlorm/elvish-stl/re
use github.com/chlorm/elvish-stl/str
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

# Parses a line from /proc/mounts into a map.
fn -parse-proc-mount {|mount|
    var s = [ (str:split ' ' $mount) ]
    var m = [
        &device-type=$s[0]
        &mount-point=$s[1]
        &file-system=$s[2]
        &mount-options=[ (str:split ',' $s[3]) ]
    ]
    if (not (==s $s[4] 0)) {
        var err = 'Failed to parse /proc/mount line: '$mount"\n"$m
        fail $err
    }
    put $m
}

# Returns all tmpfs paths from /proc/mounts
fn -get-linux-tmpfs-paths {
    for p [ (io:cat '/proc/mounts') ] {
        if (re:match '^(tmpfs|ramfs)' $p) {
            var n = (-parse-proc-mount $p)
            var m = $n['mount-point']
            # Exclude know invalid paths
            if (==s '/sys/fs/cgroup' $m) {
                continue
            }
            if (and (re:match '^/run' $m) ^
                    (not (re:match '^/run/user' $m)) ^
                    (not (re:match '^/run/shm' $m))) {
                continue
            }
            put $n
        }
    }
}

# Dumb sort that returns mounts with uid=$uid first.
fn -get-linux-tmpfs-priority {|tmpfsProcMountObjs uid|
    var high = [ ]
    var low = [ ]

    for i $tmpfsProcMountObjs {
        if (list:has $i['mount-options'] 'uid='$uid) {
            set high = [ $@high $i ]
        } else {
            set low = [ $@low $i ]
        }
    }
    put [ $@high $@low ]
}

# FIXME: untested
fn -get-macos-tmpfs-paths {
    env:get 'TMPDIR'
}

fn -get-windows-tmpfs-paths {
    env:get 'TEMP'
}

fn -get-user-tmpfs-paths {
    if $platform:is-linux {
        var uid = (os:uid)
        for i (-get-linux-tmpfs-priority [ (-get-linux-tmpfs-paths) ] $uid) {
            if (not (list:has $i['mount-options'] 'uid='$uid)) {
                put $i['mount-point']'/'$uid
            } else {
                put $i['mount-point']
            }
        }
        return
    }
    if $platform:is-windows {
        -get-windows-tmpfs-paths
        return
    }
    if $platform:is-darwin {
        -get-macos-tmpfs-paths
        return
    }

    put $E:ROOT'/tmp'
    put $E:ROOT'/var/tmp'
}

fn -try {|path|
    if $platform:is-windows {
        # FIXME: Make this a console error with instructions on how to
        #        enable this behavior.
        # Require the batch file before returning as a valid tmp dir.
        -install-windows-bat
    }

    if (not (os:is-dir $path)) {
        os:makedirs $path 2>$os:NULL
    }

    os:chmod 0700 $path

    utils:test-writeable $path
}

# Prefer first (or first largest) dir
fn -get-first-dir {|dirs &by-size=$false|
    var largest = 0
    var largest-dir = $nil
    var first = $nil
    for dir $dirs {
        var blocks = 0
        # MacOS and Windows provide a specific tmp directory so
        # we don't need to compare storage space.
        if (or $platform:is-darwin $platform:is-windows) {
            set blocks = 1
        } else {
            try {
                set blocks = (os:statfs $dir)['blocks']
            } catch e { echo $e >&2 }
        }

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
}

# Returns a writable tmpfs directory.
fn get-user {|&by-size=$false|
    var possibleDirs = [ (-get-user-tmpfs-paths) ]
    var possibleDirsStats = [&]
    for dir $possibleDirs {
        try {
            -try $dir
        } catch e {
            continue
        }
    }
    try {
        -get-first-dir $possibleDirs &by-size=$by-size
    } catch e {
        echo $e >&2
        fail 'Could not find a writeable tmpfs'
    }
}
