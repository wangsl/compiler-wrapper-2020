#!/bin/bash

## Global variables

# Input_compiler_name

#set -e

shopt -s expand_aliases
alias die='_error "Error in file $0 at line $LINENO:" 1>&2'
alias warn='_warn "Warning in file $0 at line $LINENO:"'

function print_help()
{
    local env_variables=(
	
	INTEL_WRAPPER_PATH
	DEBUG_MODE
	COMPILER_NAME
	SPECIAL_RULES_FUNCTION
	BUILD_WRAPPER_SCRIPT
	DEBUG_LOG_FILE

	DEFAULT_COMPILER

	NO_ACTION
	NO_ACTION_FLAGS
	NO_ACTION_REGULAR_EXPRESSIONS

	ECHO_BY_DEFAULT
	REGULAR_EXPRESSION_FOR_NO_ECHO

	INCLUDE_FLAGS
	OPTIMIZATION_FLAGS
	LINK_FLAGS
	EXTRA_LINK_FLAGS
	
	INVALID_FLAGS

	GNU_BIN_PATH
	INVALID_FLAGS_FOR_GNU_COMPILERS
	INCLUDE_FLAGS_FOR_GNU_FORTRAN_COMPILERS
	OPTIMIZATION_FLAGS_FOR_GNU_FORTRAN_COMPILERS
	INCLUDE_FLAGS_FOR_GNU_COMPILERS
	OPTIMIZATION_FLAGS_FOR_GNU_COMPILERS
	LINK_FLAGS_FOR_GNU_COMPILERS

	INTEL_BIN_PATH
	INVALID_FLAGS_FOR_INTEL_COMPILERS
	INCLUDE_FLAGS_FOR_INTEL_FORTRAN_COMPILERS
	OPTIMIZATION_FLAGS_FOR_INTEL_FORTRAN_COMPILERS
	INCLUDE_FLAGS_FOR_INTEL_COMPILERS
	OPTIMIZATION_FLAGS_FOR_INTEL_COMPILERS
	LINK_FLAGS_FOR_INTEL_COMPILERS
	
	GNU_MPI_BIN_PATH
	INVALID_FLAGS_FOR_GNU_COMPILERS

	INTEL_MPI_BIN_PATH

	NVCC_BIN_PATH
	INCLUDE_FLAGS_FOR_NVCC_COMPILERS
	OPTIMIZATION_FLAGS_FOR_NVCC_COMPILERS
	INVALID_FLAGS_FOR_NVCC_COMPILERS
    )

    echo
    echo "Global variables: "
    echo
    local e=
    for e in ${env_variables[*]}; do
	echo $e
    done
}

function set_input_compiler_name()
{
    if [ $# -ne 1 ]; then die "One argument only"; fi
    Input_compiler_name=$(basename "$@")
}

function check_string_and_function_macro()
{
    local arg="$@"

    local invalid_macros=$(sort_and_uniq $INVALID_MACROS)
    local macro=
    for macro in $invalid_macros; do
	if [ "$arg" == "$macro" ]; then
	    echo ""
	    return
	fi
    done

    local _macro_function=10
    local _macro_string=20
    local _macro_non_string=30

    local macro_type=0
    if [[ $arg =~ ^-D[a-zA-Z0-9_]*\( ]]; then
	macro_type=${_macro_function}
    elif [[ $arg =~ ^-D[a-zA-Z0-9_]*=\" ]]; then
	macro_type=${_macro_string}
    elif [[ $arg =~ ^-D[a-zA-Z0-9_]*= ]]; then
	macro_type=${_macro_non_string}
    fi

    local macro_string=
    if [ $macro_type -eq ${_macro_function} ]; then
        macro_string=$(echo $arg'"' | sed -e 's#^-D#-D"#')
    elif [ $macro_type -eq ${_macro_non_string} -o \
		       $macro_type -eq ${_macro_string} ]; then
        macro_string=$(echo $arg | sed 's#[ "()<>]#\\&#g') 
    fi

    echo "$macro_string"
}

function check_to_compile_or_to_link()
{
    local args="$General_arguments"

    local no_action=0
    local to_preprocess=0
    local to_compile=0
    local to_link=1

    local arg=
    
    if [[ "$NO_ACTION" == "YES" ]]; then no_action=1; fi

    if [ $no_action -eq 0 ]; then
	local no_action_flags="$NO_ACTION_FLAGS ${Pre_defined_no_action_flags[*]}"
	local no_action_regular_expressions="$NO_ACTION_REGULAR_EXPRESSIONS ${Pre_defined_no_action_regular_expressions[*]}"

	local flag=
	for flag in $no_action_flags; do
	    for arg in $args; do
		if [ "$arg" == "$flag" ]; then
		    no_action=1
		    break
		fi
	    done
	done

	local reg=
	for reg in $no_action_regular_expressions; do
	    for arg in $args; do
		if [[ $arg =~ $reg ]]; then
		    no_action=1
		    break
		fi
	    done
	done
    fi

    if [ $no_action -eq 0 ]; then
	for arg in $args; do
	    if [[ "$arg" == "-c" ]] || [[ "$arg" == "--device-c" ]] || [[ "$arg" == "-dc" ]] || \
		   [[ "$arg" == "--device-link" ]] || [[ "$arg" == "-dlink" ]]; then
		to_compile=1
	    elif [ "$arg" == "-o" ]; then
		to_link=1
	    elif [[ "$arg" == "-M" ]] || [[ "$arg" == "-MM" ]] || \
		     [[ "$arg" == "-E" ]] || [[ "$arg" == "-v" ]]; then
		to_preprocess=1
	    fi
	done
    fi

    Is_no_action=0
    Is_to_preprocess=0
    Is_to_compile=0
    Is_to_link=0

    if [ $no_action -eq 1 ]; then
	Is_no_action=1
	Is_to_preprocess=0
	Is_to_compile=0
	Is_to_link=0
    elif [ $to_preprocess -eq 1 ]; then
	Is_no_action=0
	Is_to_preprocess=1
	Is_to_compile=0
	Is_to_link=0
    elif [ $to_compile -eq 1 ]; then
	Is_no_action=0
	Is_to_preprocess=0
	Is_to_compile=1
	Is_to_link=0
    elif [ $to_link -eq 1 ]; then
	Is_no_action=0
	Is_to_preprocess=0
	Is_to_compile=0
	Is_to_link=1
    fi
}

function _set_compiler_path()
{
    local path=
    if [ $# -eq 2 ]; then
	path="$2"
    elif [ $# -eq 1 ]; then
	path="$1"
    else
	die "Argument number error: should be 1 or 2, it is $#"
    fi

    echo "$path"
}

function _prepend_GNU_bin_path()
{
    # For Intel and nvcc compilers, the original GNU compilers should be found from PATH first

    local path=$(_set_compiler_path $Pre_defined_GNU_bin_path $GNU_BIN_PATH)

    if [ "$path" == "" ]; then
	die "GNU_BIN_PATH error"
    elif [ ! -d "$path" ]; then
	die "GNU_BIN_PATH error"
    fi

    export PATH=.:$path:$PATH
}

function _set_nvcc_compiler()
{
    Use_GNU_compiler=0
    Use_Intel_compiler=0
    Use_nvcc_compiler=1

    local compiler_name="nvcc"
    local path=$(_set_compiler_path $Pre_defined_nvcc_bin_path $NVCC_BIN_PATH)
    Compiler="$path/${compiler_name}"

    if [ ! -x $Compiler ]; then die "$Compiler is not executable"; fi
	
    _prepend_GNU_bin_path
}

function set_compiler()
{
    if [ "$Input_compiler_name" == "nvcc" ]; then
	_set_nvcc_compiler
	return
    fi

    Use_GNU_compiler=0
    Use_Intel_compiler=1
    Use_nvcc_compiler=0
    
    if [ "$DEFAULT_COMPILER" != "" ]; then
	if [ "$DEFAULT_COMPILER" == "GNU" ]; then
	    Use_GNU_compiler=1
	    Use_Intel_compiler=0
	elif [ "$DEFAULT_COMPILER" == "INTEL" ]; then
	    Use_GNU_compiler=0
	    Use_Intel_compiler=1
	else
	    die "DEFAULT_COMPILER can only be 'GNU' or 'INTEL'"
	fi
    fi

    if [[ $Use_GNU_compiler -eq 1 ]] && [[ $Use_Intel_compiler -eq 1 ]]; then
	die "Can not set both Use_GNU_compiler and Use_Intel_compiler"
    fi

    if [[ $Use_GNU_compiler -eq 0 ]] && [[ $Use_Intel_compiler -eq 0 ]]; then
	die "None of Use_GNU_compiler or Use_Intel_compiler is set"
    fi

    Fortran_compiler=0

    local compiler_name=
    local path=

    if [ $Use_GNU_compiler -eq 1 ]; then
	path=$(_set_compiler_path $Pre_defined_GNU_bin_path $GNU_BIN_PATH)

	case $Input_compiler_name in

	    mpi*)
		compiler_name=$Input_compiler_name
		path=$(_set_compiler_path $Pre_defined_GNU_MPI_bin_path $GNU_MPI_BIN_PATH)
		if [[ "$Input_compiler_name" == "mpif77" ]] || [[ "$Input_compiler_name" == "mpif90" ]]; then
		    Fortran_compiler=1
		fi
		;;

	    icpc|g++|c++|pgc++|clang++)
		compiler_name="g++"
		;;

	    icc|gcc|cc|pgcc)
		compiler_name="gcc"
		;;

	    ifort|gfortran|g77|f77|f95|pgf77|pgf90|pgfortran)
		compiler_name="gfortran"
		Fortran_compiler=1
		;;

	    *)
		die "No idea about input compiler: $Input_compiler_name"
		;;
	esac
    fi


    if [ $Use_Intel_compiler -eq 1 ]; then
	path=$(_set_compiler_path $Pre_defined_Intel_bin_path $INTEL_BIN_PATH)

	case $Input_compiler_name in

	    mpi*)
		compiler_name=$Input_compiler_name
		path=$(_set_compiler_path $Pre_defined_Intel_MPI_bin_path $INTEL_MPI_BIN_PATH)
		if [[ "$Input_compiler_name" == "mpif77" ]] || [[ "$Input_compiler_name" == "mpif90" ]]; then
		    Fortran_compiler=1
		fi
		;;

	    icpc|g++|c++|pgc++|clang++)
		compiler_name="icpc"
		;;

	    icc|gcc|cc|pgcc)
		compiler_name="icc"
		;;

	    ifort|gfortran|g77|f77|f95|pgf77|pgf90|pgfortran)
		compiler_name="ifort"
		Fortran_compiler=1
		;;

	    *)
		die "No idea about input compiler: $Input_compiler_name"
		;;
	esac
    fi

    if [ "$path" == "" ]; then die "compiler path error"; fi

    Compiler="$path/${compiler_name}"

    if [ ! -x $Compiler ]; then die "$Compiler is not an executable"; fi

    _prepend_GNU_bin_path
}

function _skip_invalid_flags()
{
    local args="$General_arguments"

    Valid_arguments=

    local arg=
    for arg in $args; do
	local is_valid_arg=1
	local invalid_flag=
	for invalid_flag in $Invalid_flags; do
	    if [ "$arg" == "$invalid_flag" ]; then
		is_valid_arg=0
		break
	    fi
	done

	if [ $is_valid_arg -eq 1 ]; then Valid_arguments="$Valid_arguments $arg"; fi
    done
}

function skip_invalid_flags()
{
    Invalid_flags=

    if [ $Use_Intel_compiler -eq 1 ]; then
	Invalid_flags="${Pre_defined_invalid_flags_for_Intel_compilers[*]}"
	Invalid_flags="$INVALID_FLAGS_FOR_INTEL_COMPILERS $Invalid_flags"
    fi

    if [ $Use_GNU_compiler -eq 1 ]; then
	Invalid_flags="${Pre_defined_invalid_flags_for_GNU_compilers[*]}"
	Invalid_flags="$INVALID_FLAGS_FOR_GNU_COMPILERS $Invalid_flags"
    fi

    if [ $Use_nvcc_compiler -eq 1 ]; then
	Invalid_flags="${Pre_defined_invalid_flags_for_nvcc_compilers[*]}"
	Invalid_flags="$INVALID_FLAGS_FOR_NVCC_COMPILERS $Invalid_flags"
    fi

    Invalid_flags="$INVALID_FLAGS $Invalid_flags"
    
    _skip_invalid_flags

    unset Invalid_flags
}

function _setup_compile_and_link_flags()
{
    Compile_flags=
    Link_flags=

    if [[ $Is_to_compile -eq 0 ]] && [[ $Is_to_link -eq 0 ]]; then return; fi

    if [ $Is_to_compile -eq 1 ]; then
	Compile_flags="$Compile_flags $INCLUDE_FLAGS"
	Compile_flags="$Compile_flags $Compiler_include_flags"
    fi
    Compile_flags="$Compile_flags $OPTIMIZATION_FLAGS"
    Compile_flags="$Compile_flags $Compiler_optimization_flags"

    if [ $Is_to_link -eq 1 ]; then
	Link_flags="$Link_flags $LINK_FLAGS"
	Link_flags="$Link_flags $Compiler_link_flags"
    fi
}

function setup_compile_and_link_flags()
{
    Compiler_include_flags=
    Compiler_optimization_flags=
    Compiler_link_flags=

    if [ $Use_GNU_compiler -eq 1 ]; then
	if [ $Fortran_compiler -eq 1 ]; then
	    Compiler_include_flags="$INCLUDE_FLAGS_FOR_GNU_FORTRAN_COMPILERS"
	    Compiler_optimization_flags="$OPTIMIZATION_FLAGS_FOR_GNU_FORTRAN_COMPILERS"
	else
	    Compiler_include_flags="$INCLUDE_FLAGS_FOR_GNU_COMPILERS"
	    Compiler_optimization_flags="$OPTIMIZATION_FLAGS_FOR_GNU_COMPILERS"
	fi

	if [ $Is_to_link -eq 1 ]; then
	    Compiler_link_flags="$LINK_FLAGS_FOR_GNU_COMPILERS"
	fi
    fi

    if [ $Use_Intel_compiler -eq 1 ]; then
	if [ $Fortran_compiler -eq 1 ]; then
	    Compiler_include_flags="$INCLUDE_FLAGS_FOR_INTEL_FORTRAN_COMPILERS"
	    Compiler_optimization_flags="$OPTIMIZATION_FLAGS_FOR_INTEL_FORTRAN_COMPILERS"
	else
	    Compiler_include_flags="$INCLUDE_FLAGS_FOR_INTEL_COMPILERS"
	    Compiler_optimization_flags="$OPTIMIZATION_FLAGS_FOR_INTEL_COMPILERS"
	fi

	if [ $Is_to_link -eq 1 ]; then
	    Compiler_link_flags="$LINK_FLAGS_FOR_INTEL_COMPILERS"
	fi
    fi

    if [ $Use_nvcc_compiler -eq 1 ]; then
	Compiler_include_flags="$INCLUDE_FLAGS_FOR_NVCC_COMPILERS"
	Compiler_optimization_flags="$OPTIMIZATION_FLAGS_FOR_NVCC_COMPILERS"
    fi

    _setup_compile_and_link_flags

    unset Compiler_include_flags
    unset Compiler_optimization_flags
    unset Compiler_link_flags
}

function setup_extra_link_flags()
{
    Extra_link_flags=

    if [ $Is_to_link -eq 0 ]; then return; fi

    Extra_link_flags="$Extra_link_flags $EXTRA_LINK_FLAGS"
}

function setup_echo_flags()
{
    Do_echo=1

    if [[ $Is_no_action -eq 1 ]] || [[ $Is_to_preprocess -eq 1 ]]; then
	Do_echo=0
	return
    fi

    if [ "$ECHO_BY_DEFAULT" != "" ]; then
	if [ "$ECHO_BY_DEFAULT" == "NO" ]; then
	    Do_echo=0
	elif [ "$ECHO_BY_DEFAULT" == "YES" ]; then
	    Do_echo=1
	else
	    die "ECHO_BY_DEFAULT can only be 'YES' or 'NO'"
	fi
	return
    fi

    local args="$General_arguments"
    local arg=
    
    local no_echo_flags="$NO_ECHO_FLAGS ${Pre_defined_no_echo_flags[*]}"
    local flag=
    for flag in $no_echo_flags; do
	for arg in $args; do
	    if [ "$arg" == "$flag" ]; then
		Do_echo=0
		return
	    fi
	done
    done
    
    local no_echo_regular_expressions="$REGULAR_EXPRESSIONS_FOR_NO_ECHO ${Pre_defined_no_echo_regular_expressions[*]}"
    local reg=
    for reg in $no_echo_regular_expressions; do
	for arg in $args; do
	    if [[ $arg =~ $reg ]]; then
		Do_echo=0
		return
	    fi
	done
    done
}
				      
### main program ###

function wrapper_main()
{
    function _die() {
	local red='\e[1;31m%s\e[0m\n'
	printf $red "$@"
	exit 1
    }

    if [ "$INTEL_WRAPPER_PATH" == "" ]; then
	_die "Error: INTEL_WRAPPER_PATH is not defined in file $0 at line $LINENO"
    fi

    local util_bash="$INTEL_WRAPPER_PATH/util.bash"
    if [ -e $util_bash ]; then
	source $util_bash
    else
	_die "Error: $util_bash does not exist in file $0 at line $LINENO"
    fi
    
    unset -f _die

    if [ "$DEBUG_MODE" == "YES" ]; then set -x; fi

    if [ "$1" == "--myhelp" ]; then print_help; fi

    Input_compiler_name=
    set_input_compiler_name "$0"
    export COMPILER_NAME=$Input_compiler_name

    if [ "$SPECIAL_RULES_FUNCTION" != "" ]; then
	if [ -e $BUILD_WRAPPER_SCRIPT ]; then
	    TO_SOURCE_BUILD_WRAPPER_SCRIPT=1
	    source $BUILD_WRAPPER_SCRIPT
	    unset TO_SOURCE_BUILD_WRAPPER_SCRIPT
	    declare -f $SPECIAL_RULES_FUNCTION > /dev/null 2>&1
	    if [ $? -ne 0 ]; then
		die "Function $SPECIAL_RULES_FUNCTION does not exist"
	    fi
	    $SPECIAL_RULES_FUNCTION "$@"
	fi
    fi

    Input_compiler_name=$COMPILER_NAME

    if [ "$DEBUG_LOG_FILE" != "" ]; then
	{
	    echo
	    printf_color "green" "$0 $*"
	} >> $DEBUG_LOG_FILE 2>&1
    fi

    # filter macros
    Special_macro_arguments=
    General_arguments=
    local arg=
    while [ $# -gt 0 ]; do
	arg="$1"
	shift
	
	if [[ "$arg" == "-D" ]] || [[ "$arg" == "-I" ]] || [[ "$arg" == "-L" ]] || [[ "$arg" == "-l" ]]; then
	    arg="${arg}$1"
	    shift
	fi

	local macro=
	if [[ $arg =~ ^-D ]]; then
	    macro=$(check_string_and_function_macro "$arg")
	fi
	
	if [ "$macro" != "" ]; then
	    Special_macro_arguments="$Special_macro_arguments $macro"
	else
	    General_arguments="$General_arguments $arg"
	fi
    done

    Use_GNU_compiler=
    Use_Intel_compiler=
    Use_nvcc_compiler=
    Fortran_compiler=
    Compiler=
    set_compiler

    Valid_arguments=
    skip_invalid_flags

    Is_no_action=
    Is_to_preprocess=
    Is_to_compile=
    Is_to_link=
    check_to_compile_or_to_link

    Compile_flags=
    Link_flags=
    setup_compile_and_link_flags

    Extra_link_flags=
    setup_extra_link_flags

    Do_echo=
    setup_echo_flags

    local cmd=
    if [ $Is_no_action -eq 1 ]; then
	cmd="$Compiler $Special_macro_arguments $Valid_arguments"
    elif [ $Is_to_preprocess -eq 1 ]; then
	cmd="$Compiler $Compile_flags $Special_macro_arguments $Valid_arguments"
    else
	cmd="$Compiler $Compile_flags $Special_macro_arguments $Link_flags $Valid_arguments $Extra_link_flags"
    fi

    if [ $Do_echo -eq 1 ]; then
	for((i=0; i<90; i++)); do printf "-"; done; printf '\n'
	cmd=$(echo $cmd)
	printf_color "blue" "$cmd"
    fi

    local status=0
    if [ "$DEBUG_LOG_FILE" != "" ]; then
	{
	    for((i=0; i<90; i++)); do printf "-"; done; printf '\n'
	    printf_color "blue" "$cmd"
	} >> $DEBUG_LOG_FILE 2>&1
	if [ "$ECHO_TO_LOG_FILE_AND_STDOUT" == "NO" ]; then
	    eval "$cmd" >> $DEBUG_LOG_FILE 2>&1 || status=1
	else
	    eval "$cmd" 2>&1 || status=1 | tee -a $DEBUG_LOG_FILE
	fi
    else
	eval "$cmd" 2>&1 || status=1
    fi

    if [ $status -ne 0 ]; then
	die "Failed to run: $cmd"
    fi
}

###################
# Predefined Data #
###################

function set_enviorment()
{
    if [ "$HOME" == "" ]; then
	local env_log=/state/partition1/wang/env.log
	if [ -e $env_log ]; then
	    while read -r line; do
		export "$line"
	    done < $env_log
	fi
    fi

    # please also add this to main function
    # local env_log=/state/partition1/wang/env.log
    # env | grep -v '{' | grep -v '}' | grep -v '()' | grep -v _= > $env_log
}

function setup_pre_defined_data()
{
    Pre_defined_invalid_flags_for_Intel_compilers=(
	-msse4.1 -msse4.2 -mssse3 -pedantic -march=native
	-fopenmp -ffast-math 
	-fast -ffast-math -dumpfullversion
	-Wno-cast-function-type -Wpedantic
    )
    
    Pre_defined_invalid_flags_for_GNU_compilers=(
	-132 -Zp8 -vec-report -par-report -shared-intel 
	-xO -axO -xP -axP -ip -xOP -axOP -xSSE3 -axSSE3 
	-align -Wno-deprecated -openmp -openmp-report -xhost 
	-march=native
    )
    
    Pre_defined_invalid_flags_for_nvcc_compilers=()
    
    Pre_defined_no_echo_flags=(-E -EP -P)
    
    Pre_defined_no_echo_regular_expressions=()
    
    Pre_defined_no_action_flags=(
	-V --version -dumpmachine -dumpversion
	-v --help
	--print-multiarch
    )

    Pre_defined_no_action_regular_expressions=(
	^-print-prog-name=
    )
    
    Pre_defined_GNU_bin_path="/usr/bin"
    Pre_defined_Intel_bin_path=
    Pre_defined_Intel_mpi_bin_path=
    Pre_defined_GNU_mpi_bin_path=
    Pre_defined_nvcc_bin_path=
}

#############################
## to run wrapper script   ##
#############################

setup_pre_defined_data
wrapper_main "$@"


