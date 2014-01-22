wait_for_success_msg () {
    [[ $# = 2 ]] || {
        echo >&2 'usage: wait_for_success_msg success_msg logfile'
        return 2
    }
    
    success_msg=$1
    logfile=$2
    let count=0 max=18

    while [ $count -le $max ]
    do
        if ! grep "${success_msg}" $2
        then  printf >&2 ".";#  output message.
        else  break; # successful message.
        fi
        let count=$count+1;# increment attempts count.
        [ $count -eq $max ] && {
            echo >&2 "FAIL: Execeeded max attemps "
            exit 1
        }
        sleep 10; # wait 10s before trying again.
    done
}
