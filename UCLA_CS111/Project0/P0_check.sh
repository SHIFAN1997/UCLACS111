#!/bin/bash
#
# sanity check script for Project 0
#	tarball name
#	tarball contents
#	student identification 
#	use of expected functions
#	error free build
#	reak cehck of make check
#	real check of make dist
#	real check of make clean
#	unrecognized parameters
#	copy stdin to stdout
#	proper --input=
#	proper --output=
#	--segfault
#	--catch --segfault
#
#
LIBRARY_URL="www.cs.ucla.edu/classes/cs111/Software"
LAB="lab0"
README="README"
MAKEFILE="Makefile"

SOURCES="lab0.c"
SNAPS="backtrace.png breakpoint.png"

EXPECTED="$SOURCES $SNAPS"
SUFFIXES=""

PGM="lab0"
PGMS=$PGM

TIMEOUT=5

# expected return codes
EXIT_OK=0
EXIT_ARG=1
EXIT_BADIN=2
EXIT_BADOUT=3
EXIT_FAULT=4
SIG_SEGFAULT=139

let errors=0

if [ -z "$1" ]
then
	echo usage: $0 your-student-id
	exit 1
else
	student=$1
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
checkTarget check
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

echo "... checking make check"
make check 2> STDERR
testRC $? 0
let errors+=$?
# ... we expect error output here

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
	./$p --bogus > /dev/null 2>STDERR
	testRC $? $EXIT_ARG
	if [ ! -s STDERR ]
	then
		echo "No Usage message to stderr for --bogus"
		let errors+=1
	else
		echo -n "        "
		cat STDERR
	fi
done

echo "... exercise bad --input from a nonexistent file"
./$PGM --input=NON_EXISTENT_FILE 2>STDERR
testRC $? $EXIT_BADIN
if [ ! -s STDERR ]
then
	echo "No error message to STDERR"
	let errors+=1
else
	echo -n "        "
	cat STDERR
fi

echo "... exercise bad --output to an unwritable file"
touch CANT_TOUCH_THIS
chmod 444 CANT_TOUCH_THIS
./$PGM --output=CANT_TOUCH_THIS 2>STDERR
testRC $? $EXIT_BADOUT
if [ ! -s STDERR ]
then
	echo "No error message to STDERR"
	let errors+=1
else
	echo -n "        "
	cat STDERR
fi
rm -f CANT_TOUCH_THIS

# see if it causes and catches segfaults correctly
echo "... exercise --segfault option"
./$PGM --segfault
testRC $? $SIG_SEGFAULT

echo "... exercise --catch --segfault option"
./$PGM --catch --segfault 2>STDERR
testRC $? $EXIT_FAULT
if [ ! -s STDERR ]
then
	echo "No error message to STDERR"
	let errors+=1
else
	echo -n "        "
	cat STDERR
fi

# generate some pattern data
dd if=/dev/urandom of=RANDOM bs=1024 count=1 2> /dev/null

# exercise normal copy operations
echo "... copy stdin -> stdout"
timeout $TIMEOUT ./$PGM < RANDOM > STDOUT
testRC $? $EXIT_OK
cmp RANDOM STDOUT > /dev/null
if [ $? -eq 0 ]
then
	echo "        data comparison ... OK"
else
	echo "        data comparison ... FAILURE"
	let errors+=1
fi
rm STDOUT

echo "... copy --input -> stdout"
timeout $TIMEOUT ./$PGM --input=RANDOM > STDOUT
testRC $? $EXIT_OK
cmp RANDOM STDOUT > /dev/null
if [ $? -eq 0 ]
then
	echo "        data comparison ... OK"
else
	echo "        data comparison ... FAILURE"
	let errors+=1
fi
rm STDOUT

echo "... copy stdin -> --output"
timeout $TIMEOUT ./$PGM < RANDOM --output=OUTPUT
testRC $? $EXIT_OK
cmp RANDOM OUTPUT > /dev/null
if [ $? -eq 0 ]
then
	echo "        data comparison ... OK"
else
	echo "        data comparison ... FAILURE"
	let errors+=1
fi
rm OUTPUT

echo "... copy --input -> --output"
timeout $TIMEOUT ./$PGM --input=RANDOM --output=OUTPUT
testRC $? $EXIT_OK
cmp RANDOM OUTPUT > /dev/null
if [ $? -eq 0 ]
then
	echo "        data comparison ... OK"
else
	echo "        data comparison ... FAILURE"
	let errors+=1
fi


echo "... use of expected routines"
for r in getopt_long signal strerror close 'dup2\|dup'
do
	c=`grep -c "$r(" *.c`
	if [ $c -gt 0 ]
	then
		echo "        $r ... OK"
	else
		echo "        $r ... NO REFERENCES FOUND"
		let errors+=1
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
