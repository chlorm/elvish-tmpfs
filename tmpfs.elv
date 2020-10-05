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
use github.com/chlorm/elvish-stl/regex
use github.com/chlorm/elvish-stl/utils


fn -try [path]{
  if (not (os:is-dir $path)) {
    os:makedirs $path 2>&-
  }
  os:chmod 0700 $path
  local:s = (os:statfs $path)
  local:type = $s[type]
  if (not (or (==s $type 'tmpfs') (==s $type 'ramfs'))) {
    fail
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
    } except _ {
      # Ignore
    }
    if (eq $uid $nil) {
      fail 'Could not determine UID'
    }

    local:possible-dirs = [
      $E:ROOT'/run/user/'$uid
      $E:ROOT'/dev/shm/'$uid
      $E:ROOT'/run/shm/'$uid
      $E:ROOT'/tmp/'$uid
      $E:ROOT'/var/tmp/'$uid
    ]
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
    local:largest-dir = ''
    local:first = ''
    for local:dir $possible-dirs {
      local:blocks = 0
      try {
        blocks = $possible-dirs-stats[$dir][blocks]
      } except _ { }
      if (==s $first '') {
        first=$dir
      }
      if (> $blocks $largest) {
        largest = $blocks
        largest-dir = $dir
      }
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
get-user-tmpfs
