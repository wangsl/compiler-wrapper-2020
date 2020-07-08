#!/bin/bash

# $Id$

function printf_color()
{
    local black1='\e[1;30m%s\e[0m\n'
    local red1='\e[1;31m%s\e[0m\n'
    local green1='\e[1;32m%s\e[0m\n'
    local yellow1='\e[1;33m%s\e[0m\n'
    local blue1='\e[1;34m%s\e[0m\n'
    local magenta1='\e[1;35m%s\e[0m\n'
    local cyan1='\e[1;36m%s\e[0m\n'

    local black='\e[0;30m%s\e[0m\n'
    local red='\e[0;31m%s\e[0m\n'
    local green='\e[0;32m%s\e[0m\n'
    local yellow='\e[0;33m%s\e[0m\n'
    local blue='\e[0;34m%s\e[0m\n'
    local magenta='\e[0;35m%s\e[0m\n'
    local cyan='\e[0;36m%s\e[0m\n'

    local color=""
    local message=
    
    if [ $# -eq 2 ]; then
	color="$1"
	message="$2"
    elif [ $# -eq 1 ]; then
	color=""
	message="$1"
    fi
    
    case $color in
	
	black) color=$black;;
	black1) color=$black1;;

	red) color=$red;;
	red1) color=$red1;;

	green) color=$green;;
	green1) color=$green1;;
	
	yellow) color=$yellow;;
	yellow1) color=$yellow1;;
	
	blue) color=$blue;;
	blue1) color=$blue1;;

	magenta) color=$magenta;;
	magenta1) color=$magenta1;;
	
	cyan) color=$cyan;;
	cyan1) color=$cyan1;;

	*) color=$black;;
    esac

    printf "${color}%s" "$message"
}

function _error()
{
    local arg=
    for arg in "$@"; do
	printf_color "red1" "$arg"
    done
    exit 1
}

function _warn()
{
    local arg=
    for arg in "$@"; do
	printf_color "magenta1" "$arg"
    done
}

shopt -s expand_aliases
alias die='_error "Error in file $0 at line $LINENO" 1>&2'
alias warn='_warn "Warning in file $0 at line $LINENO"'

function _pend_to_env_variable()
{
    if [ $# -ne 4 ]; then die "need 4 arguements, it is $# now"; fi
    
    local action="$1"
    local env_name="$2"
    local env_args="$3"
    local field_separator="$4"
    
    if [[ $action -eq 1 ]]; then
	local cmd="export $env_name=\"\$${env_name}${field_separator}${env_args}\""
    elif [[ $action -eq 0 ]]; then
	local cmd="export $env_name=\"${env_args}${field_separator}\$${env_name}\""
    else
	die "first argument should be 1 (append) or 0 (prepend)"
    fi
    
    eval "$cmd"
}

function append_to_env_variable()
{
    local env_name="$1"
    local env_args="$2"
    local field_separator=" "
    if [[ $# -eq 3 ]]; then field_separator="$3"; fi
    
    _pend_to_env_variable 1 "$env_name" "$env_args" "$field_separator"
}

function prepend_to_env_variable()
{
    local env_name="$1"
    local env_args="$2"
    local field_separator=" "
    if [[ $# -eq 3 ]]; then field_separator="$3"; fi

    _pend_to_env_variable 0 "$env_name" "$env_args" "$field_separator"
}

function LD_LIBRARY_PATH_to_rpath()
{
    local rpath=
    local ld_lib_paths=$(echo $LD_LIBRARY_PATH | tr ':' '\n' | sort -u)
    
    local lib_path=
    for lib_path in $ld_lib_paths; do
	if [ "$lib_path" != "." ]; then
	    if [ -d $lib_path ]; then
		rpath="-Wl,-rpath=$lib_path $rpath"
	    fi
	fi
    done

    echo "$rpath"
}

function sort_and_uniq()
{
    if [[ "$*" != "" ]]; then
	echo "$@" | tr ' ' '\n' | sort -u
    fi
}
