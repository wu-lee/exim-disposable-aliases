#!/bin/bash

# This test suite needs to be run with exim on the path,
# and with the appropriate privileges for it to execute the
# tests (which may mean root).  However, it should be safe and
# will not send any mail.

fails=0

function die() {
    echo $* >&2
    exit 1
}

db=sqlite.db
rm -f "$db" &&
sqlite3 "$db" <../schema.sql &&
sqlite3 "$db" <<EOF || die failed to init $db
insert into aliases (stem, recipients) values ('pimpernel', 'percy'), ('double', 'alice'), ('double', 'bob'), ('double', 'carol'), ('double', 'dave@example.com'), ('defaulton', 'percy');
insert into authorised (stem, id, driver) values ('pimpernel', 'nick', 'dovecot_plain');
insert into stem_configs (stem, default_remaining) values ('defaulton', -1);
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
    shift
echo $cmd "$@" >&2
    $cmd $*
}

# We use 'read' here to guarantee an order
while true; do
    read -r email || die unexpected end of data
    read -r subj  || die unexpected end of data
    result=$(sed "s/Subject: .*/Subject: $subj/" <test1.email | testexim "$email"  -oMai root)
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
got a disposable mail candidate infixed with no deliveries remaining

foo.2.zoo@bar
test 
got a disposable mail candidate infixed with 2 deliveries remaining

alpha.pimpernel@bar
test 
got a known alias 'pimpernel' for 'percy' prefix 'alpha'

beta.pimpernel@bar
test 
got a known alias 'pimpernel' for 'percy' prefix 'beta'

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: remaining=0

alpha.pimpernel@bar
!on 
enable prefix 'alpha'

alpha.pimpernel@bar
test 
deliver to 'percy': remaining=-1

alpha.pimpernel@bar
test 
deliver to 'percy': remaining=-1

alpha.pimpernel@bar
!off 
disable prefix 'alpha'

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: remaining=0

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: remaining=0

alpha.pimpernel@bar
!2 
allow 2 more to prefix 'alpha'

alpha.pimpernel@bar
test 
deliver to 'percy': remaining=2

alpha.pimpernel@bar
test 
deliver to 'percy': remaining=1

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: remaining=0

alpha.pimpernel@bar
test 
no more mail permitted to alpha.pimpernel: remaining=0

alpha.pimpernel@bar
!report 
All *.pimpernel alias deliveries remaining:
prefix=alpha remaining=0 delivered=4 rejected=6 
prefix=beta remaining=0 delivered=0 rejected=1 

foo.pimpernel@bar
!report
All *.pimpernel alias deliveries remaining:
prefix=alpha remaining=0 delivered=4 rejected=6 
prefix=beta remaining=0 delivered=0 rejected=1 

?.pimpernel@bar
!report
All *.pimpernel alias deliveries remaining:
prefix=alpha remaining=0 delivered=4 rejected=6 
prefix=beta remaining=0 delivered=0 rejected=1 

foo.3.pimpernel@bar
test
deliver to 'percy': remaining=3

foo.pimpernel@bar
test
deliver to 'percy': remaining=2

foo.9.pimpernel@bar
test
deliver to 'percy': remaining=1

foo.pimpernel@bar
!report
All *.pimpernel alias deliveries remaining:
prefix=alpha remaining=0 delivered=4 rejected=6 
prefix=beta remaining=0 delivered=0 rejected=1 
prefix=foo remaining=0 delivered=3 rejected=0 

?.pimpernel@bar
!report
All *.pimpernel alias deliveries remaining:
prefix=alpha remaining=0 delivered=4 rejected=6 
prefix=beta remaining=0 delivered=0 rejected=1 
prefix=foo remaining=0 delivered=3 rejected=0 

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
got a disposable mail candidate infixed with 99999 deliveries remaining

uno.double@bar
!on
got a known alias 'double' for 'alice,bob,carol,dave@example.com' prefix 'uno'
enable prefix 'uno'

uno.double@bar
test
got a known alias 'double' for 'alice,bob,carol,dave@example.com' prefix 'uno'
Deliver message to: alice@
Deliver message to: bob@
Deliver message to: carol@
Deliver message to: dave@example.com

alpha.defaulton@bar
first email
No email infix counter, using configured default_remaining counter -1
got a disposable mail candidate infixed with no deliveries remaining
got a known alias 'defaulton' for 'percy' prefix 'alpha'
deliver to 'percy': remaining=-1

alpha.5.defaulton@bar
second email
Using email infix counter 5
got a disposable mail candidate infixed with 5 deliveries remaining
got a known alias 'defaulton' for 'percy' prefix 'alpha'
deliver to 'percy': remaining=-1

alpha.defaulton@bar
third email
No email infix counter, using configured default_remaining counter -1
got a disposable mail candidate infixed with no deliveries remaining
got a known alias 'defaulton' for 'percy' prefix 'alpha'
deliver to 'percy': remaining=-1

beta.5.defaulton@bar
first email
Using email infix counter 5
got a disposable mail candidate infixed with 5 deliveries remaining
got a known alias 'defaulton' for 'percy' prefix 'beta'
deliver to 'percy': remaining=5
EOF


# Test authentication checks
# We use 'read' here to guarantee an order
while true; do
    read -r email || die unexpected end of data
    read -r subj  || die unexpected end of data
    read -r flags || die unexpected end of data
    result=$(sed "s/Subject: .*/Subject: $subj/" <test1.email | testexim "$email" $flags)    
    printf "%s $email: $subj\n" "$flags"
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
alpha.pimpernel@bar
!on
-oMa 127.0.0.1 -oMaa dovecot_plain -oMai nick
source looks authenticated, id: 'nick' host: '127.0.0.1' auth driver: 'dovecot_plain'
enable prefix 'alpha'

alpha.pimpernel@bar
!on
-oMa 1.2.3.4 -oMaa dovecot_plain -oMai nick
source looks authenticated, id: 'nick' host: '1.2.3.4' auth driver: 'dovecot_plain'
enable prefix 'alpha'

alpha.pimpernel@bar
!on
-oMa 127.0.0.1 -oMai nick
source doesn't look authenticated, id: 'nick' host: '127.0.0.1' auth driver: ''
deliver to 'percy': remaining=-1

alpha.pimpernel@bar
!on
-oMai root
source looks authenticated, id: 'root' host: '' auth driver: ''
enable prefix 'alpha'

alpha.pimpernel@bar
!on
-oMa 1.2.3.4 -oMai root
source doesn't look authenticated, id: 'root' host: '1.2.3.4' auth driver: ''
deliver to 'percy': remaining=-1

alpha.pimpernel@bar
!on
-oMa 1.2.3.4 -oMai nick
source doesn't look authenticated, id: 'nick' host: '1.2.3.4' auth driver: ''
deliver to 'percy': remaining=-1
EOF

echo "failed: $fails"
exit $fails

