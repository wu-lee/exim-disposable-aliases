#!/bin/bash

fails=0

db=sqlite.db
rm -f "$db" &&
sqlite3 "$db" <../schema.sql &&
sqlite3 "$db" <<EOF || { echo failed to init $db; exit 1; }
insert into aliases (stem, recipients) values ('pimpernel', 'percy');
EOF


export DISP_ALIASES_DB=$(readlink -f "$db")
../expand-macros <"../filter2" >"filter2"

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
while IFS=: read -r email subj message; do
    result=$(sed "s/Subject: .*/Subject: $subj/" <test1.email | testexim "$email")
    if printf "$result" | grep -q -e "$message"; then
	echo "ok   - $sj: $message"
    else
	echo "fail - $sj: $message"
	printf "$result\n" | sed 's/^/    /'
	fails=$(($fails + 1))
    fi
#printf "$result\n"
#printf "xxxxx$sj\n"
done <<EOF
foo@bar: test :not a disposable mail candidate
foo.zoo@bar: test :got a disposable mail candidate with no counter
foo.2.zoo@bar: test :got a disposable mail candidate with a counter: 2
alpha.pimpernel@bar: test :got a known alias 'pimpernel' for 'percy' prefix 'alpha'
beta.pimpernel@bar: test :got a known alias 'pimpernel' for 'percy' prefix 'beta'
alpha.pimpernel@bar: test :no more mail permitted to alpha.pimpernel: counter=0
alpha.pimpernel@bar: !on :set 'alpha' counter on
alpha.pimpernel@bar: test :deliver to 'percy': counter=-1
alpha.pimpernel@bar: test :deliver to 'percy': counter=-1
alpha.pimpernel@bar: !off :set 'alpha' counter off
alpha.pimpernel@bar: test :no more mail permitted to alpha.pimpernel: counter=0
alpha.pimpernel@bar: test :no more mail permitted to alpha.pimpernel: counter=0
alpha.pimpernel@bar: !2 :set 'alpha' counter 2
alpha.pimpernel@bar: test :deliver to 'percy': counter=2
alpha.pimpernel@bar: test :deliver to 'percy': counter=1
alpha.pimpernel@bar: test :no more mail permitted to alpha.pimpernel: counter=0
alpha.pimpernel@bar: test :no more mail permitted to alpha.pimpernel: counter=0
alpha.pimpernel@bar: !report :alpha.pimpernel alias: 0 mails left
foo.pimpernel@bar: !report: foo.pimpernel alias: unknown prefix 'foo'
?.pimpernel@bar: !report: unknown prefix '?'
foo.3.pimpernel@bar: test: deliver to 'percy': counter=3
foo.pimpernel@bar: test: deliver to 'percy': counter=2
foo.9.pimpernel@bar: test: deliver to 'percy': counter=1
foo.9.pimpernel@bar: test: no more mail permitted to foo.pimpernel: counter=0
?.pimpernel@bar: !reportall: pimpernel aliases
EOF

echo "failed: $fails"
exit $fails

