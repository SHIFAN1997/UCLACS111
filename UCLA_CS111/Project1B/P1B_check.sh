#!/bin/bash
#
# sanity check script for Project 1B
#	extract tar file
#	required README fields (ID, EMAIL, NAME)
#	required Makefile targets (clean, dist)
#	make default
#	make dist
#	make clean (returns directory to untared state)
#	make default, success, creates client/server
#	client detects/reports illegal arguments
#	client detects/reports unwritable log file
#	trivial shell session
#	compressed trivial shell session
#	presence of orphans
#
LAB="lab1b"
README="README"
MAKEFILE="Makefile"


SUFFIXES="c"
CLIENT=lab1b-client
SERVER=lab1b-server
PGMS="$CLIENT $SERVER"

PTY_TEST=pty_test
FILTER=logfilter
LIBRARY_URL="www.cs.ucla.edu/classes/cs111/Software"
TIMEOUT=1

EXIT_OK=0
EXIT_ARG=1

let errors=0

if [ -z "$1" ]
then
	echo usage: $0 your-student-id
	exit 1
else
	student=$1
fi

# make sure the tarball has the right name
tarball="$LAB-$student.tar.gz"
if [ ! -s $tarball ]
then
	echo "ERROR: Unable to find submission tarball:" $tarball
	exit 1
fi

# get copy of our grading/checking functions
if [ -s functions.sh ]; then
	source functions.sh
else
	wget $LIBRARY_URL/functions.sh 2> /dev/null
	if [ $? -eq 0 ]; then
		>&2 echo "Downloading functions.sh from $LIBRARY_URL"
		source functions.sh
	else
		>&2 echo "FATAL: unable to pull test functions from $LIBRARY_URL"
		exit -1
	fi
fi

# read the tarball into a test directory
TEMP=`pwd`/"CS111_test.$LOGNAME"
if [ -d $TEMP ]
then
	echo Deleting old $TEMP
	rm -rf $TEMP
fi
mkdir $TEMP
unTar $LAB $student $TEMP
cd $TEMP

# note the initial contents
dirSnap $TEMP $$

echo "... checking for README file"
checkFiles $README
let errors+=$?

echo "... checking for submitter ID in $README"
ID=`getIDs $README $student`
let errors+=$?

echo "... checking for submitter email in $README"
EMAIL=`getEmail $README`
let errors+=$?

echo "... checking for submitter name in $README"
NAME=`getName $README`
let errors+=$?

echo "... checking slip-day use in $README"
SLIPDAYS=0
slips=`grep "SLIPDAYS:" $README`
if [ $? -eq 0 ]
then
	slips=`echo $slips | cut -d: -f2 | tr -d \[:space:\]`
	if [ -n "$slips" ]
	then
		if [[ $slips == ?([0-9]) ]]
		then
			SLIPDAYS=$slips
			echo "    $SLIPDAYS days"
		else
			echo "    INVALID SLIPDAYS: $slips"
			let errors+=1
		fi
	else
		echo "    EMPTY SLIPDAYS ENTRY"
		let errors+=1
	fi
else
	echo "    no SLIPDAYS: entry"
fi

echo "... checking for other expected files"
checkFiles $MAKEFILE $EXPECTED
let errors+=$?

# make sure we find files with all the expected suffixes
if [ -n "$SUFFIXES" ]; then
	echo "... checking for other files of expected types"
	checkSuffixes $SUFFIXES
	let errors+=$?
fi

echo "... checking for required Make targets"
checkTarget clean
let errors+=$?
checkTarget dist
let errors+=$?

echo "... checking for required compillation options"
checkMakefile Wall
let errors+=$?
checkMakefile Wextra
let errors+=$?

# make sure we can build the expected program
echo "... building default target(s)"
make 2> STDERR
testRC $? 0
let errors+=$?
noOutput STDERR
let errors+=$?

echo "... checking make dist"
make dist 2> STDERR
testRC $? 0
let errors+=$?
noOutput STDERR
let errors+=$?

checkFiles $TARBALL
if [ $? -ne 0 ]; then
	echo "ERROR: make dist did not produce $tarball"
	let errors+=1
fi

echo " ... checking make clean"
rm -f STDERR
make clean
testRC $? 0
let errors+=$?
dirCheck $TEMP $$
let errors+=$?

#
# now redo the default make and start testing functionality
#
echo "... redo default make"
make 2> STDERR
testRC $? 0
let errors+=$?
noOutput STDERR
let errors+=$?

echo "... checking for expected products"
checkPrograms $PGMS
let errors+=$?

# see if they detect and report invalid arguments
for p in $PGMS
do
	echo "... $p detects/reports bogus arguments"
	./$p --bogus < /dev/tty > /dev/null 2>STDERR
	testRC $? $EXIT_ARG
	stty sane
	if [ ! -s STDERR ]
	then
		echo "No Usage message to stderr for --bogus"
		let errors+=1
	else
		echo -n "        "
		cat STDERR
	fi
done

# get copies of the testing programs
downLoad $PTY_TEST $LIBRARY_URL "c" "-lpthread"
downLoad $FILTER $LIBRARY_URL "c" ""

echo "... $CLIENT detects/reports system unwritable log file"
timeout $TIMEOUT ./$CLIENT --log=/tmp < /dev/tty > /dev/null 2>STDERR
testRC $? 1
if [ ! -s STDERR ]
then
	echo "No error message to stderr for non-writable log file"
	let errors+=1
else
	cat STDERR
fi

#
# function to check for orphaned client or server
#
orphan_check() {
	ps -u > ORPHANS.OUT
	for p in $CLIENT $SERVER
	do
		grep $p ORPHANS.OUT > /dev/null
		if [ $? -eq 0 ]
		then
			let errors+=1
			echo "!!! ORPHAN $p after $1"
			grep $p ORPHANS.OUT
		killall $p
	fi
	done
}

# generate a pseudo-random starting point to avoid multi-student conflicts
let PORT=6661
random=`date`
base=`echo $random | cksum | cut -f 1 -d ' '`
PORT=$((PORT + (base % 1000)))

# run a trivial shell session and see if we get plausible shell output
echo "... testing trivial shell session"
./$SERVER --port=$PORT > SVR_OUT 2> SVR_ERR &
./$PTY_TEST ./$CLIENT --port=$PORT --log=LOG_1 > STDOUT 2> STDERR <<-EOF
	PAUSE 1
	EXPECT "/bin/bash"
	SEND "echo \$SHELL\n"
	WAIT 1
	SEND "exit 6\n"
	PAUSE 1
	CLOSE
EOF
testRC $? 0
if [ $? -ne 0 ]; then
	echo   "ERROR: shell did not properly execute commands"
	let errors+=$?
fi

# see if the expected command was in the log
./$FILTER --tag=SENT LOG_1 > LOG_SENT_1
grep "echo" LOG_SENT_1 > /dev/null
if [ $? -eq 0 ]; then
	echo "   log SENT commands ... PASS"
else
	echo "   log SENT commands ... FAIL"
	let errors+=1
fi

# see if the expected response was in the log
./$FILTER --tag=RECEIVED LOG_1 > LOG_RECV_1
if [ -s LOG_RECV_1 ]; then
	echo "   log RECEIVED commands ... PASS"
	grep "bash" LOG_RECV_1 > /dev/null
	if [ $? -eq 0 ]; then
		echo "   plausible shell output ... PASS"
	else
		echo "   plausible shell output ... FAIL"
		let errors+=1
	fi
else
	echo "   log REVEIVED commands ... FAIL"
	let errors+=1
fi

# see if the server properly reported shell exit status
grep "STATUS=" SVR_ERR > /dev/null
if [ $? -eq 0 ]; then
	grep "STATUS=6" SVR_ERR > /dev/null
	if [ $? -eq 0 ]; then
		echo "   server correctly reports shell exit status ... PASS"
	else
		echo "   server correctly reports shell exit status ... FAIL"
		let errors+=1
	fi
else
	echo "   server reports shell exit status ... FAIL"
	let errors+=1
fi

orphan_check "trivial shell session"

echo "... testing compressed shell session"
let PORT+=1
./$SERVER --port=$PORT --compress > SVR_OUT 2> SVR_ERR &
./$PTY_TEST ./$CLIENT --compress --port=$PORT --log=LOG_2 > STDOUT 2> STDERR <<-EOF
	PAUSE 1
	EXPECT "/bin/bash"
	SEND "echo \$SHELL\n"
	WAIT 1
	SEND "exit 7\n"
	PAUSE 1
	CLOSE
EOF
testRC $? 0
if [ $? -ne 0 ]; then
	echo   "ERROR: shell did not properly execute commands"
	let errors+=1
fi

# see if the expected command was in the log
./$FILTER --tag=SENT LOG_2 > LOG_SENT_2
grep "echo" LOG_SENT_2 > /dev/null
if [ $? -eq 0 ]; then
	echo "   compressed SENT commands ... FAIL"
	let errors+=1
else
	echo "   compressed SENT commands ... PASS"
fi

# see if the expected response was in the log
./$FILTER --tag=RECEIVED LOG_2 > LOG_RECV_2
grep "bash" LOG_RECV_2 > /dev/null
if [ $? -eq 0 ]; then
	echo "   compressed shell output ... FAIL"
	let errors+=1
else
	echo "   compressed shell output ... PASS"
fi

# see if the server properly reported shell exit status
grep "STATUS=7" SVR_ERR > /dev/null
if [ $? -eq 0 ]; then
	echo "   shell properly receives commands ... PASS"
else
	echo "   shell properly receives commands ... FAIL"
	let errors+=1
fi

orphan_check "compressed shell session"

echo "... checking use of zlib"
for r in deflateInit deflateEnd deflate inflateInit inflateEnd inflate
do
	grep "$r(" *.c > /dev/null
	if [ $? -ne 0 ]
	then
		echo "No calls to $r"
		let errors+=1
	else
		echo "    ... $r ... OK"
	fi
done

echo
if [ $SLIPDAYS -eq 0 ]
then
	echo "THIS SUBMISSION WILL USE NO SLIP-DAYS"
else
	echo "THIS SUBMISSION WILL USE $SLIPDAYS SLIP-DAYS"
fi

echo
echo "THE ONLY STUDENTS WHO WILL RECEIVE CREDIT FOR THIS SUBMISSION ARE:"
commas=`echo $ID | tr -c -d "," | wc -c`
let submitters=commas+1
let f=1
while [ $f -le $submitters ]
do
	id=`echo $ID | cut -d, -f$f`
	mail=`echo $EMAIL | cut -d, -f$f`
	echo "    $id    $mail"
	let f+=1
done
echo

# delete temp files, report errors, and exit
cleanup $$ $errors
