#!/bin/bash 
#
#
# Copyright (c) 2016-2017 LabKey Corporation
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
#
# /etc/rc.d/init.d/xvfb 
# 
# Author: Brian Connolly (LabKey.org) 
# 
# chkconfig: 345 98 90 
# description: Starts Virtual Framebuffer process to enable the  
# LabKey server to use R. 
# 
### BEGIN INIT INFO
# Provides:          xvfb
# Required-Start:    $network $syslog $remote_fs
# Should-Start:      $named $syslog $time
# Required-Stop:     $network $syslog
# Should-Stop:       
# Default-Start:     3 4 5
# Default-Stop:      0 1 6
# Description:       X Virtual Frame Buffer for R
### END INIT INFO

#
XVFB_OUTPUT=${LABKEY_HOME}/Xvfb.out
XVFB=/usr/bin/Xvfb
XVFB_OPTIONS=":2 -nolisten tcp -shmem -extension GLX"

#Xvfb "<%= @displayNumber =%> -ac -pixdepths 8 -shmem -extension GLX


# Source function library.    
[ -r /etc/init.d/functions ] && . /etc/init.d/functions

start() {
    echo -n "Starting : X Virtual Frame Buffer "
    $XVFB $XVFB_OPTIONS >>$XVFB_OUTPUT 2>&1&
    RETVAL=$?
    echo
    return $RETVAL
}

stop() {
    echo -n "Shutting down : X Virtual Frame Buffer"
    echo
    killproc Xvfb
    echo
    return 0
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
        echo "Usage: xvfb {start|stop}"
        exit 1
        ;;
esac
exit $?
