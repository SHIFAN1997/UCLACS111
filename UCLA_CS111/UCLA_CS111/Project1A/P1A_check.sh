#!/bin/bash
#
# usage: P1A_check.sh id [existing directory]
#
# sanity check script for Project 1A
#	
#	existance of tarball
#	expected deliverables
#	expected tags in README
#	default build
#	make clean
#	make dist
#	default build after make clean
#	produces expected program
#	recognizes and complains about bogus arguments
#
LAB="lab1a"
README="README"
MAKEFILE="Makefile"

EXPECTED=""
SUFFIXES="c"
PGM="./lab1a"
PGMS="$PGM"
PTY_TEST=pty_test
LIBRARY_URL="www.cs.ucla.edu/classes/cs111/Software"

EXIT_OK=0
EXIT_ARG=1

let PRESERVE=0
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
if [ -n "$2" -a -d "$2" ]
then
	TEMP=$2
else
	TEMP=`pwd`/"CS111_test.$LOGNAME"
	if [ -d $TEMP ]
	then
		echo Deleting old $TEMP
		rm -rf $TEMP
	fi
	mkdir $TEMP
	unTar $LAB $student $TEMP
fi
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
	$p --bogus < /dev/tty > /dev/null 2>STDERR
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

# get a copy of the PTY exercisor
downLoad $PTY_TEST $LIBRARY_URL "c" "-lpthread"

#
# exercise keyboard to stdout processing
#
./$PTY_TEST --modes ./$PGM > STDOUT 2> STDERR <<-EOF
	PAUSE 1
	MODES DURING
	SEND "^D"
	PAUSE 1
	CLOSE
EOF
echo

BEFORE=`grep START STDERR | cut -d: -f2`
DURING=`grep DURING STDERR | cut -d: -f2`
AFTER=`grep END STDERR | cut -d: -f2`

echo "... confiriming disable of ICANON"
LFLAG=`echo $DURING | cut -d" " -f3`
ICANON=0x02
if ((($LFLAG & $ICANON) != 0))
then
	echo "... ICANON still on ($LFLAG)"
	let errors+=1
fi

echo "... confirming disable of ECHO"
ECHO=0x10
if ((($LFLAG & $ECHO) != 0))
then
	echo "... ICANON still on ($LFLAG)"
	let errors+=1
fi

echo "... checking mode restoration on exit"
if [ "$BEFORE" != "$AFTER" ]; then
	echo "... FAIL (before=$BEFORE ; after=$AFTER)"
	let errors+=1
fi

echo "... confirming character at a time echo"
./$PTY_TEST ./$PGM > STDOUT 2> STDERR <<-EOF
	EXPECT "a"
	SEND "a"
	WAIT 1

	EXPECT "b"
	SEND "b"
	WAIT 1

	SEND "^D"
	CLOSE
EOF
RC=$?
if [ $RC -ne 0 ]
then
	echo "FAIL ... STDERR dump follows:"
	let errors+=1
	cat STDERR
fi

echo "... confirming batch character echo and processing"
./$PTY_TEST ./$PGM > STDOUT 2> STDERR <<-EOF
	EXPECT "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	SEND "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	WAIT 1

	SEND "^D"
	CLOSE
EOF
RC=$?
if [ $RC -ne 0 ]; then
	echo "FAIL ... STDERR dump follows:"
	let errors+=1
	cat STDERR
fi

echo "... confirming cr->crlf translation"
./$PTY_TEST ./$PGM > STDOUT 2> STDERR <<-EOF
	EXPECT "abc\r\n"
	SEND "abc\r"
	WAIT 1

	SEND "^D"
	CLOSE
EOF
RC=$?
if [ $RC -ne 0 ]; then
	echo "... FAIL"
	let errors+=1
fi

echo "... confirming basic shell input/output"
./$PTY_TEST ./$PGM --shell > STDOUT 2> STDERR <<-EOF
	PAUSE 1
	EXPECT "/bin/bash"
	SEND "echo \$SHELL is running test script\r"
	WAIT 1
	SEND "exit\r"
	SEND "^D"
	CLOSE
EOF
RC=$?
if [ ! -s STDOUT ]; then
	echo "FAIL ... shell session produces no output"
	echo "dump of STDERR follows:"
	cat STDERR
	let errors+=1
fi

echo "... confirming input was processed by shell"
grep '/bin/bash' STDOUT > /dev/null
if [ $? -ne 0 ]; then
	let errors+=1
	echo "... FAIL echo \$SHELL"
	echo STDERR DUMP FOLLOWS
	cat STDERR
	echo STDOUT DUMP FOLLOWS
	cat STDOUT 
fi

echo "... confirming correct large-burst input processing"
./$PTY_TEST --rate=0 ./$PGM --shell > STDOUT 2> STDERR <<-EOF
	PAUSE 1
	EXPECT "/bin/bash"
	SEND "echo \$SHELL is running test script\r"
	WAIT 1
	SEND "exit\r"
	SEND "^D"
	CLOSE
EOF
RC=$?
grep '/bin/bash' STDOUT > /dev/null
if [ $? -ne 0 ]; then
	let errors+=1
	echo "... FAIL echo \$SHELL"
	echo STDERR DUMP FOLLOWS
	cat STDERR
	echo STDOUT DUMP FOLLOWS
	cat STDOUT 
	echo
fi

echo "... confirming cr->nl mapping on shell input"
./$PTY_TEST ./$PGM --shell > STDOUT 2> STDERR <<-EOF
	# we do this to confirm that the shell is running
	PAUSE 1
	EXPECT "/bin/bash\r\n"
	SEND "echo \$SHELL\r"
	WAIT 1

	SEND "exit\r"
	SEND "^D"
	CLOSE
EOF
RC=$?
if [ $RC -ne 0 ]; then
	let errors+=1
	echo "... FAIL"
fi

echo ... confirming shell exit status reporting
./$PTY_TEST ./$PGM --shell > STDOUT 2> STDERR <<-EOF
	# we do this to confirm that the shell is running
	PAUSE 1
	EXPECT "/bin/bash"
	SEND "echo \$SHELL\r"
	WAIT 1

	SEND "exit 9\r"
	SEND "^D"
	PAUSE 1
	CLOSE
EOF
# note that STDERR from $PGM will be in STDOUT from $PTYTEST
grep 'STATUS=9' STDOUT > STATUS
if [ $? -ne 0 ]; then
	let errors+=1
	echo "FAIL ... expected STATUS=9"
fi

echo ... confirming interrupt generation to shell
./$PTY_TEST ./$PGM --shell > STDOUT 2> STDERR <<-EOF
	SEND "trap 'echo got sigint' sigint\r"

	# we do this to confirm that the shell is running
	PAUSE 1
	EXPECT "/bin/bash"
	SEND "echo \$SHELL\r"
	WAIT 1

	EXPECT "sigint"
	SEND "^C\r"
	WAIT 1

	SEND "^D"
	CLOSE
EOF
#
# NOTE: we send \r beacuse of a "feature" in recent bash
#
count=`grep -c 'got sigint' STDOUT`
if [ $count -ne 2 ]; then
	let errors+=1
	echo "FAIL ... shell did nnot report receiving SIGINT"
fi

echo ... confirming EOF generation to shell
./$PTY_TEST ./$PGM  --shell > STDOUT 2> STDERR <<-EOF
	# we do this to confirm that the shell is running
	PAUSE 1
	EXPECT "/bin/bash"
	SEND "echo \$SHELL\r"
	WAIT 1

	SEND "^D"
	CLOSE
EOF
grep 'STATUS=0' STDOUT > /dev/null
if [ $? -ne 0 ]; then
	let errors+=1
	echo "FAIL ... expected exit w/STATUS=0"
	echo STDOUT dump follows
	cat STDOUT
fi

#
# check for orphans
#
echo "... checking for orphaned processes"
ps -u > STDOUT
grep lab1a STDOUT > /dev/null
if [ $? -eq 0 ]
then
	echo "!!! ORPHANS"
	grep lab1a STDOUT
	let errors+=1
	killall lab1a
fi

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
