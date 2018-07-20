
# NAME: Christopher Aziz
# EMAIL: caziz@ucla.edu
# ID: 000000000

CFLAGS = -Wall -Wextra -g
CC = gcc
STUDENT_ID = 000000000
DIST_FILES = Makefile README lab0.c breakpoint.png backtrace.png
checks = check_success check_invalid_option check_invalid_input check_invalid_output check_segfault_catch

# build executable
build: lab0.c
	$(CC) $(CFLAGS) lab0.c -o lab0

# smoke-test to see if required arguments are supported
check: clean build $(checks)
	@echo "Passed smoke-test"

check_success:
	@echo "a\nb\nc\n" > smoke_test_input.txt;
	@./lab0 --input smoke_test_input.txt --output smoke_test_output.txt 2> /dev/null; \
	if [ $$? -ne 0 ]; then \
		echo "Failed smoke-test: successful copy did result in exit code 0"; \
		exit 1; \
	fi
	@rm -f smoke_test_input.txt smoke_test_output.txt;

check_invalid_option:
	@./lab0 --invalid_argument 2> /dev/null > /dev/null; \
	if [ $$? -ne 1 ]; then \
		echo "Failed smoke-test: invalid option did not result in exit code 1"; \
		exit 1; \
	fi

check_invalid_input:
	@./lab0 --input smoke_test_nonexistent_file.txt 2> /dev/null > /dev/null; \
        if [ $$? -ne 2 ]; then \
                echo "Failed smoke-test: invalid input did not result in exit code 2"; \
		exit 1; \
	fi

check_invalid_output:
	@touch smoke_test_output.txt
	@chmod -w smoke_test_output.txt
	@./lab0 --output smoke_test_output.txt 2> /dev/null > /dev/null; \
	if [ $$? -ne 3 ]; then \
                echo "Failed smoke-test: invalid output did not result in exit code 3"; \
		exit 1; \
        fi
	@rm -f smoke_test_output.txt

check_segfault_catch:
	@./lab0 --segfault --catch 2> /dev/null > /dev/null; \
        if [ $$? -ne 4 ]; then \
                echo "Failed smoke-test: caught segfault did not result in exit code 4"; \
		exit 1; \
        fi

# delete all files created by Makefile
clean:
	@rm -f *.o *.tar.gz smoke_test_input.txt smoke_test_output.txt lab0

# build distribution tarball
dist:
	@tar -czf lab0-$(STUDENT_ID).tar.gz $(DIST_FILES)
