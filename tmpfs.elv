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


use re
use github.com/chlorm/elvish-stl/os
use github.com/chlorm/elvish-stl/path
use github.com/chlorm/elvish-stl/utils


# Set globally to only run once
local:df-output = [ (e:df) ]


fn -is-tmp-dir [dir]{
  for local:line $df-output {
    if (re:match '^?(tmpfs|ramfs).*'$dir $line) {
      return
    }
  }
  fail 'tmpfs/ramfs dir does not exist: '$dir
}

fn -dir-exists-and-writeable [dir]{
  if (not (os:is-dir $dir)) {
    os:makedirs $dir
  }
  os:chmod '0700' $dir
  utils:test-writeable $dir
}

# Returns a writable tmpfs directory.
fn get-user-tmpfs {
  try {
    local:uid = (get-env UID)
    try {
      uid = (id -u)
    } except _ {
      # Ignore
    }
    if (==s '' $uid) {
      fail 'Could not determine UID'
    }

    local:possible-dirs = [
      $E:ROOT'/dev/user/'$uid
      $E:ROOT'/dev/shm'
      $E:ROOT'/run/shm'
      $E:ROOT'/tmp'
      $E:ROOT'/var/tmp'
    ]
    for local:dir $possible-dirs {
      if ?(-is-tmp-dir $dir) {
        if (!=s $uid (path:basename $dir)) {
          dir = (path:join $dir $uid)
        }
        -dir-exists-and-writeable $dir
        set-env XDG_RUNTIME_DIR $dir
        put $dir
        break
      }
    }
  } except {
    fail 'Could not find a writeable tmpfs'
  }
}

