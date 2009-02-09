#!/bin/bash -e
# Copyright 2009, Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Invoke SCons in a predictable fashion on different platforms.
#
# This script is intended (along with hammer.bat) to be the main entry
# point to the software construction toolkit.  You can either invoke this file
# as a shell script, or you can source this file in order to bring the
# functions below into your bash environment.
#
# You will need to define the env variable SCONS_DIR, which points to an
# install of SCons which contains a scons-local subdirectory.
#
# Environment variables used all the time:
#   HAMMER_OPTS        Command line options for hammer/SCons,
#                      in addition to any specified on the
#                      command line.
#
# Environment variables used for IncrediBuild (Xoreax Grid
# Engine) support (only available under cygwin):
#   HAMMER_XGE         If set to 1, enable IncrediBuild
#   HAMMER_XGE_PATH    Path to IncrediBuild install.  Required
#                      if it was not installed in the default
#                      location:
#                      (%ProgramFiles%\Xoreax\IncrediBuild).
#   HAMMER_XGE_OPTS    Additional options to pass to IncrediBuild.
#
# Sample values for HAMMER_OPTS:
#   -j %NUMBER_OF_PROCESSORS%             # on Windows
#   -j $(sysctl -n hw.logicalcpu)         # on Mac OS X
#   -j $(grep -c processor /proc/cpuinfo) # on Linux
#      Run parallel builds on all processor cores, unless
#      explicitly overridden on the command line.
#   -j12
#      Always run 12 builds in parallel; a good default if
#      HAMMER_XGE=1 or when using distcc.
#   -s -k
#      Don't print commands; keep going on build failures.

case $OSTYPE in
  cygwin*)
      function sct_hammer() {
        local sct_dir="$(dirname $0)"

        # Invoke scons via the software construction toolkit wrapper.
        # NOTE: Remove -O and -OO from the following to make
        # asserts execute.
        local hammer_cmd=("python"
                          "-O" "-OO"
                          "$COVERAGE_HOOK"
                          "$sct_dir/wrapper.py"
                          "$HAMMER_OPTS"
                          "--site-dir=\"$sct_dir/site_scons\"")

        if [[ $HAMMER_XGE == 1 ]]; then
          local xge_path=$(cygpath -u -a "$PROGRAMFILES/Xoreax/IncrediBuild")
          if [[ ! -x "$xge_path/xgConsole.exe" ]]; then
            echo "Warning: xgConsole.exe not found in '$xge_path'"
            echo "NOT using IncrediBuild."
          else
            new_path="$new_path:$xge_path"
            hammer_cmd=("XGConsole.exe"
                        "$HAMMER_XGE_OPTS"
                        "/command='${hammer_cmd[@]}'")
          fi
        fi

        local pythonpath="$SCONS_DIR"
        pythonpath="$pythonpath;$SCONS_DIR/scons-local"

        local cmd=('PWD=$(cygpath -m -a .)'
          'SHELL=$(cygpath -w -a $SHELL)'
          "PATH=\"$new_path\""
          "PYTHONPATH=\"$pythonpath\""
          "${hammer_cmd[@]}"
          "$@")
        if [[ ${SCT_WRAPPER_OPTS##*--verbose} != $SCT_WRAPPER_OPTS ]]; then
          echo "${cmd[@]}"
        fi
        eval "${cmd[@]}"
      }
      ;;
  darwin*|linux*)
      function sct_hammer() {
        local sct_dir="$(dirname $0)"
        local pythonpath="$SCONS_DIR"
        pythonpath="$pythonpath:$SCONS_DIR/scons-local"

        # Invoke scons via the software construction toolkit wrapper.
        # NOTE: Remove -O and -OO from the following to make
        # asserts execute.
        local cmd=("PYTHONPATH=\"$pythonpath\""
                   'python'
                   '-O' '-OO'
                   "$COVERAGE_HOOK"
                   "${sct_dir}/wrapper.py"
                   "$HAMMER_OPTS"
                   "--site-dir=\"${sct_dir}/site_scons\""
                   "$@")
        if [[ ${SCT_WRAPPER_OPTS##*--verbose} != $SCT_WRAPPER_OPTS ]]; then
          echo "${cmd[@]}"
        fi
        eval "${cmd[@]}"
      }
  ;;
esac

# Only execute this block if we are NOT sourcing this file (i.e. if we
# invoke this file as a script, then run this, if we are only
# interested in defining the functions for our bash environment, then
# we don't run this).
if [[ -z $PS1 ]]; then
  sct_hammer "$@"
fi
