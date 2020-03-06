# Copyright (c) 2018, Cody Opel <codyopel@gmail.com>
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


use github.com/chlorm/elvish-xdg/xdg


# FIXME: implement a module for checking and setting directory permissions.
#        Maybe implement multiple methods via ls, getfacl & stat.

fn -create-user-tmpfs-dir [dir]{
  try {
    mkdir -p $dir
  } except _ {
    fail 'Failed to create dir: '$dir
  }
  try {
    chmod '0700' $dir
  } except _ {
    fail 'Failed to change mode of directory: '$dir
  }
}

fn -test-write-permission [dir]{
  try {
    local:file = $dir'/test-write-file'
    if ?(test -f $file) {
      rm $file
    }
    touch $file
    rm $file
  } except _ {
    fail $dir' is not writeable'
  }
}

fn -dir-exists-and-writeable [dir]{
  # TODO: fix permissions
  if (not ?(test -d $dir)) {
    -create-user-tmpfs-dir $dir
  }
  -test-write-permission $dir
}

# Returns a writable tmpfs directory.
# TODO: Separate creation of tmpfs directories, we currently create them as
#       a writability test.
fn get-user-tmpfs {
  try {  # Use XDG_RUNTIME_DIR if it is set.
    local:xdg-runtime-dir = (xdg:get-dir XDG_RUNTIME_DIR)
    local:xdg-cache-home = (xdg:get-dir XDG_CACHE_HOME)
    # XDG_CACHE_HOME is the fallback and means we are likely not using tmpfs.
    if (or (==s $xdg-runtime-dir $xdg-cache-home) (==s $xdg-runtime-dir '')) {
      fail
    }

    -dir-exists-and-writeable $xdg-runtime-dir

    put $xdg-runtime-dir
  } except _ {  # Fallback to searching for a writable tmpfs.
    try {
      local:uid = ''
      try {
        uid = (id -u)
      } except _ {
        uid = $E:UID
      }
      if (==s $uid '') {
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
        local:tmpfs-exist = ''
        try {
          tmpfs-exist = (df | grep '^\(tmpfs\|ramfs\).*'$dir)
        } except _ {
          tmpfs-exist = ''
        }
        if (==s $tmpfs-exist '') {
          continue
        }

        if (not (has-suffix $dir $uid)) {
          dir = $dir'/'$uid
        }
        -dir-exists-and-writeable $dir
        E:XDG_RUNTIME_DIR = $dir
        put $dir
        break
      }
    } except {
      fail 'Could not find a writeable tmpfs'
    }
  }
}

fn mount-xdg-cache-on-tmpfs [tmpfs]{
  local:xdg-cache-home = (xdg:get-dir XDG_CACHE_HOME)
  if (!=s $tmpfs $xdg-cache-home) {
    ln -s $tmpfs $xdg-cache-home
  }
}
