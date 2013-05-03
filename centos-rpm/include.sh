
die() {
   [[ $# -gt 1 ]] && { 
	    exit_status=$1
        shift        
    } 
    printf >&2 "ERROR: $*\n"
    exit ${exit_status:-1}
}
