# NAME : Fan Shi
# EMAIL : fanshi2@g.ucla.edu
# ID : 805256911

default:
	gcc -Wall -Wextra lab1b-client.c -o lab1b-client -lz
	gcc -Wall -Wextra lab1b-server.c -o lab1b-server -lz

clean:
	rm -f lab1b-client lab1b-server lab1b-805256911.tar.gz

dist:
	tar -czvf lab1b-805256911.tar.gz lab1b-client.c lab1b-server.c Makefile README
