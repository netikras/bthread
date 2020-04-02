#!/bin/bash --posix
#set -x

: <<README
This is an implementation of parallel execution in shell. In short, it allows to spawn multiple
different commands, detach them from main shell, wait untill they are completed, retrieve and
print outputs of all the spawned commands. E.g.:

#######################################################################
mint:~/workspace/bthread$ tstart uptime
[1] 22002
mint:~/workspace/bthread$ tstart 'vmstat 10 2'
[1] 22017
mint:~/workspace/bthread$ time wait_all_immed 
::::::::::::: [14/22002 /proc/8088/fd/14]
 > uptime

11:06:56 up 10 days, 22:55, 46 users,  load average: 2,31, 2,12, 2,26

::::::::::::: [15/22017 /proc/8088/fd/15]
 > vmstat 10 2

procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 1  0 9465128 2377060 636864 13532000    1    2    19    24    1    1  7  5 88  0  0
 1  0 9465128 2379260 636880 13528352    0    0     0   326 5621 18963  8  6 86  0  0


real	0m8,733s
user	0m0,202s
sys     0m0,154s
mint:~/workspace/bthread$
#######################################################################

In the above example bthread waited for all the threads to complete. Once any thread completes,
all its output is printed to the stdout. That means, STDOUT and STDERR are combined.

While bthread was initially written in BASH, it was designed to be POSIX-compliant and should run 
on other shells as well.

In order to improve execution performance bthread avoids spawning subshells. Everything (except for
a few _eval_ statements and the subprocess spawner) is executed at the same shell level. This is
achieved by utilising shell scopes: called functions CAN alter caller's variables. In bthread all
called functions alter a caller's variable *result*. So bear that in mind
README



OK=0;
NOK=1;

CR=$'\r'
LF=$'\n'
TAB=$'\t'

T_ID=()
T_TID=()
T_CMD=()
T_OUTF=()
T_OUTP=()
T_TITLE=()


IFS=" ${LF}${TAB}"

trap terminate_all EXIT

## This is a library
libbthread::log() {
    local level=${1:-DEBUG}
    local message=${2:-}
    my_pid
    printf "[${level}] ${$}/${_r} ${message}\n" >>/tmp/libbthread.log
}

sleep() {
    if [ -x /bin/sleep ] ; then
        /bin/sleep ${@}
    else
        read -t${1} </dev/zero
    fi
}

my_pid() {
    _r=${BASHPID:-$( :;$SHELL -c 'echo ${PPID}' && :; )}
}

terminate_thread() {
    local id=${1:?ID not given. Cannot terminate}
    local tid=${T_TID[id]};
    if [ -n "${tid}" ] && [ -d /proc/${tid} ] ; then
        /bin/kill -9 ${tid}
    fi
}

terminate_all() {
    for id in ${T_ID[@]} ; do
        terminate_thread ${id}
    done
}





nop() {
    :;
}

sprintf() {
    printf -v ${@}
}

close_fd() {
    local fd=${1:?FD not given. Cannot close}
    libbthread::log DEBUG "Closing fd: ${fd}"
    eval "exec ${fd}>&-"
}

clear_thread() {
    local id=${1:?ID not given. Cannot clear}
    unset T_ID[id]
    unset T_TID[id]
    unset T_CMD[id]
    unset T_OUTF[id]
    unset T_OUTP[id]
    unset T_TITLE[id]
    close_fd ${id}
}

getNextFd() {
    local file;
    local fd;
    local used;
    result=;
    
    
    for file in /dev/fd/* ; do 
        fd=${file##*/}; 
        used[fd]=true; 
    done

    for id in {0..65535} ; do 
        if [ -z "${used[id]}" ] && [ -z "${T_ID[id]}" ] ; then 
            result=${id}; 
            break; 
        fi
    done
}


open_file() {
    local fd=${1}
    my_pid
    local target="/tmp/__tmpfile_${_r}"
    result=;
    
    if [ -z "${fd}" ] ; then
        getNextFd;
        fd=${result:?Cannot get next FD. Cannot open file};
    fi;
    
    target="${target}_${fd}"
    > ${target}
    libbthread::log DEBUG "Opening fd ${fd} to ${target}"
    eval "exec ${fd}<>${target}"
    /bin/rm -f "${target}"

    result=${fd};
}

tstart() {
    local cmd=${1:?Thread CMD not given. Cannot start}
    local id=${#T_ID[@]}
    my_pid
    local outf="/proc/${_r}/fd"
    local fd;
    result=;

    open_file;

    fd=${result}
    outf="${outf}/${fd}"

    T_ID[id]=${fd}
    T_CMD[id]="${cmd}"
    T_OUTF[id]="${outf}"
    T_TITLE[id]=${THEADER:-${cmd}}

    libbthread::exec "${cmd}" "${outf}" "${outf}" 2>/dev/null
#    ( eval '${cmd}' >"${outf}" 2>"${outf}" ) &
    _r=${!}

    T_TID[id]="${_r}"

    result=${id}

    libbthread::log DEBUG "Started thread id=${id} with outf: ${outf} / ${T_OUTF[id]}, TID: ${_r} / ${T_TID[id]}, cmd: ${cmd}"
}

libbthread::exec() {
    local cmd=${1:?CMD missing}
    local outf=${2:-/dev/null}
    local errf=${3:-/dev/null}
    libbthread::log TRACE "Will execute in new subshell: ${cmd}"
    ( 
        libbthread::log TRACE "Executing in new subshell: ${cmd}"; 
        eval '${cmd}' >"${outf}" 2>"${errf}" ; 
        libbthread::log TRACE "Execution completed. Output should be written to OUT:${outf}, ERR:${errf}" 
    ) &
    _r=${!}
}


is_running() {
    local id=${1:?Thread ID not given. Cannot check whether running}
    local pid=${T_TID[id]}
    local my_pid=${BASHPID}
    result=false

    if [ -d "/proc/${pid:--}" ] ; then
        local pid ppid name state stuff;
        read _pid name state ppid stuff </proc/${pid}/stat
        libbthread::log TRACE "Checking if thread PID ${pid} parent ${ppid} is owned by us: ${my_pid}" ## BASHPID ???
        if [ "${ppid}" = "${my_pid}" ] ; then result=true; return ${OK}; fi;
#        read _pid name state ppid stuff </proc/${ppid}/stat
#        libbthread::log TRACE "Checking2 if thread PID ${pid} parent ${ppid} is owned by us: ${my_pid}" ## BASHPID ???
#        if [ "${ppid}" = "${my_pid}" ] ; then result=true; return ${OK}; fi;
    else
        libbthread::log DEBUG "PID /proc/${pid} not found"
    fi

    libbthread::log DEBUG "Process ${pid} is no longer running"
    return ${NOK}
}


collect_finished() {
    local id=${1:?ID not given. Cannot collect}
    local file=${T_OUTF[id]}
    local fd=${T_ID[id]}
    result=;

    libbthread::log DEBUG "Collecting results from id=${id}, file=${file}"
    #read -d$'\x01' result <"${file}" || [ -n "${result}" ] || {
    if [ -f "${file}" ] ; then
        read -d$'\x01' result <"${file}"
    else
        libbthread::log DEBUG "A hard-to-catch error occurred. Here's some debug info - pass it over to the dev"
        libbthread::log DEBUG "$(ulimit -a)"
        my_pid
        mypid=${_r}
        libbthread::log DEBUG "Current PID:          $$/${mypid}"
        libbthread::log DEBUG "Initiated with pid:   ${T_OUTF[id]}"
        libbthread::log DEBUG "TID[${id}]:           ${T_TID[id]}"
        libbthread::log DEBUG "Current thread FDs:   $(ls -l /proc/${T_TID[id]}/fd/ 2>&1)"
        libbthread::log DEBUG "Current MY FDs:       $(ls -l /proc/${mypid}/fd/ 2>&1)"
    fi

    T_OUTP[id]="${result}"

    libbthread::log DEBUG "Collected ${id}"
    close_fd "${fd}"
}

print_outp() {
    local id=${1:?ID not given. Cannot print output}
    local BUFFER="";

    printf "::::::::::::: [%s/%s %s]\n > %s\n\n%s\n\n" "${id}" "${T_TID[id]}" "${T_OUTF[id]}" "${T_TITLE[id]}" "${T_OUTP[id]}"
}

wait_all_immed() {
    local cmd=${1:-nop}
    local id;
    while [[ "${#T_OUTP[@]}" -ne "${#T_OUTF[@]}" ]] ; do
        for id in ${T_ID[@]} ; do
            if [ -n "${T_OUTP[id]}" ] ; then continue; fi;
            is_running "${id}"

            if [ "${?}" = "${NOK}" ] ; then
                collect_finished "${id}"
                ${cmd} "${id}"
            fi
        done
        sleep .1
    done
}

wait_all_seq() { ## FIXME smth is broken here. processes/files get lost. _immed does not have this problem
    local cmd=${1:-nop}
    local id;
    for id in ${T_ID[@]} ; do
        result=;
        while [ "${result}" != "false" ] ; do
            sleep .1;
            is_running "${id}"
        done;

        collect_finished "${id}"
        ${cmd} "${id}"
    done
}



print_all_seq() {
    wait_all_seq print_outp
}
print_all_immed() {
    wait_all_immed print_outp
}


