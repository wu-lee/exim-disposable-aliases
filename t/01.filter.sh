#!/bin/bash

fails=0

function die() {
    echo $* >&2
    exit 1
}

db=sqlite.db
rm -f "$db" &&
sqlite3 "$db" <../schema.sql &&
sqlite3 "$db" <<EOF || die failed to init $db
insert into aliases (stem, recipients) values ('pimpernel', 'percy');
EOF


export DISP_ALIASES_DB=$(readlink -f "$db")
../expand-macros <"../filter" >"filter2"

function parse_addr() { 
    local email="$2"
    local local_part="${email%%@*}"
    local domain="${email#*@}"
    local non_prefix="${local_part##*.}"
    local prefix="${local_part:0:-${#non_prefix}}"

    printf "$1" "${prefix:-''}" "${non_prefix:-''}" "${domain:-''}"
}



## Test the parse_addr function
declare -A parse_addr_data=(
    [foo@bar]="'' foo bar"
    [foo.doo@bar]="foo. doo bar"
    [foo.zoo.doo@bar]="foo.zoo. doo bar"
)

for email in "${!parse_addr_data[@]}"; do
    result=$(parse_addr '%s %s %s' "$email")
    if [[ "$result" == "${parse_addr_data[$email]}" ]]; then
        printf "ok   - $email -> $result\n"
    else
        printf "fail - $email -> $result\n"
        fails=$(($fails + 1))
    fi
done


## Test the filter in exim

function testexim() {
    local cmd=$(parse_addr 'exim -bfp %s -bfl %s -bfd %s -bf filter2' "$1")
    $cmd
}

# We use 'read' here to guarantee an order
email=gamma.pimpernel@bar
while true; do
    read -r email || die unexpected end of data
    read -r subj  || die unexpected end of data
    result=$(sed "s/Subject: .*/Subject: $subj/" <test1.email | testexim "$email")    
    printf "$email: $subj\n"
    while true; do
        # End testing if we see the end of data
        read -r message || break 2
        
        # End this sequence of messages on blank line
        [ -z "$message" ] && break

        if printf "$result" | grep -q -Fe "$message"; then
            echo "ok   - $message"
        else
            echo "fail - $message"
            printf "$result\n" | sed 's/^/    /'
            fails=$(($fails + 1))
        fi
    done
done <<EOF
foo@bar
test 
not a disposable mail candidate

foo.zoo@bar
test 
got a disposable mail candidate with no counter

foo.2.zoo@bar
test 
got a disposable mail candidate with a counter: 2

alpha.pimpernel@bar
test 
got a known alias 'pimpernel' for 'percy' prefix 'alpha'

beta.pimpernel@bar
test 
got a known alias 'pimpernel' for 'percy' prefix 'beta'

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: counter=0

alpha.pimpernel@bar
!on 
set 'alpha' counter on

alpha.pimpernel@bar
test 
deliver to 'percy': counter=-1

alpha.pimpernel@bar
test 
deliver to 'percy': counter=-1

alpha.pimpernel@bar
!off 
set 'alpha' counter off

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: counter=0

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: counter=0

alpha.pimpernel@bar
!2 
set 'alpha' counter 2

alpha.pimpernel@bar
test 
deliver to 'percy': counter=2

alpha.pimpernel@bar
test 
deliver to 'percy': counter=1

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: counter=0

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: counter=0

alpha.pimpernel@bar
!report 
All *.pimpernel alias deliveries remaining:
prefix=alpha counter=0
prefix=beta counter=0

foo.pimpernel@bar
!report
All *.pimpernel alias deliveries remaining:
prefix=alpha counter=0 
prefix=beta counter=0 

?.pimpernel@bar
!report
All *.pimpernel alias deliveries remaining:
prefix=alpha counter=0 
prefix=beta counter=0 

foo.3.pimpernel@bar
test
deliver to 'percy': counter=3

foo.pimpernel@bar
test
deliver to 'percy': counter=2

foo.9.pimpernel@bar
test
deliver to 'percy': counter=1

foo.pimpernel@bar
!report
All *.pimpernel alias deliveries remaining:
prefix=alpha counter=0 
prefix=beta counter=0 
prefix=foo counter=0 

?.pimpernel@bar
!report
All *.pimpernel alias deliveries remaining:
prefix=alpha counter=0 
prefix=beta counter=0 
prefix=foo counter=0 

..pimpernel@bar
test
not a disposable mail candidate, skipping

.pimpernel@bar
test
not a disposable mail candidate, skipping

a.a.pimpernel@bar
test
not a disposable mail candidate, skipping

a.999999.pimpernel@bar
test
not a disposable mail candidate, skipping

a.-9.pimpernel@bar
test
not a disposable mail candidate, skipping

a.9.9.pimpernel@bar
test
not a disposable mail candidate, skipping

a.99999.pimpernel@bar
test
got a disposable mail candidate with a counter: 99999
EOF

echo "failed: $fails"
exit $fails

