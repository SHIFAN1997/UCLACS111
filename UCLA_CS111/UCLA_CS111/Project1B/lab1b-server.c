// NAME : Fan Shi
// EMAIL : fanshi2@g.ucla.edu
// ID : 805256911
#include <stdlib.h>
#include <stdio.h>
#include <getopt.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <termio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <poll.h>
#include <signal.h>
#include <sys/socket.h>
#include <netdb.h>
#include <sys/stat.h>
#include <zlib.h>
#define buffer_size 256

int pipe_pc[2];
int pipe_cp[2];
pid_t cpid;
struct pollfd fds[2];
int compress_command = 0;
int port_command = 0;

int port_index;
int sock_fd;
int sock_fd2;

z_stream strm1;
z_stream strm2;

void quit_message() {
    int status = 0;
    //  get the shell's exit status
    waitpid(0, &status, 0);
    fprintf(stderr, "SHELL EXIT SIGNAL=%d STATUS=%d\n", WTERMSIG(status), WEXITSTATUS(status));
}

void interrupt_handler(int sig){
  if(sig == SIGINT){
    kill(cpid, SIGINT);
  }

  if(sig == SIGPIPE){
    exit(1);
  }
}

void Child_process(){
  close(pipe_cp[0]);
  close(pipe_pc[1]);

  dup2(pipe_pc[0], 0);
  dup2(pipe_cp[1], 1);
  dup2(pipe_cp[1], 2);

  close(pipe_cp[1]);
  close(pipe_pc[0]);
  char *temp[2];
  temp[0] = "/bin/bash";
  temp[1] = NULL;

  if(execvp("/bin/bash", temp) == -1){
    fprintf(stderr, "failure in execvp() : %s", strerror(errno));
    close(sock_fd);
    close(sock_fd2);
    exit(1);
  }
}

void Parent_process(){
  close(pipe_pc[0]);
  close(pipe_cp[1]);
  fds[0].fd = sock_fd2;
  fds[0].events = POLLIN | POLLHUP | POLLERR;

  fds[1].fd = pipe_cp[0];
  fds[1].events = POLLIN | POLLHUP | POLLERR;

  while(1){
    int factor = poll(fds, 2, 0);
    if(factor == -1){
      fprintf(stderr, "ERROR IN POLL(). \n");
      close(sock_fd2);
      close(sock_fd);
      exit(1);
    }

    if(fds[0].revents & POLLIN){
      char buffer[buffer_size];
      int counter = 0;
      counter = read(sock_fd2, buffer, buffer_size);
      if(counter < 0){
        fprintf(stderr, "ERROR IN READ FROM SOCK2");
        kill(0, SIGTERM);
      }
      /*else if(counter == 0 ){
	kill(0, SIGTERM);
      }*/

      for(int i = 0; i < counter; i++){
        char curr = buffer[i];
        if(curr == 0X0D || curr == 0X0A){
          char temp = 0X0A;
          write(pipe_pc[1], &temp, 1 );
        }

        else if(curr == 0X04){
          close(pipe_pc[1]);
        }

        else if(curr == 0X03){
          kill(cpid, SIGINT);
        }

        else{
          write(pipe_pc[1], &curr, 1);
        }
      }
    }

    if(fds[0].revents & (POLLERR | POLLHUP)){
      fprintf(stderr, "ERROR IN READING");
      exit(1);
    }

    if(fds[1].revents & POLLIN){
      char buffer2[buffer_size];
      int counter2;
      counter2 = read(pipe_cp[0], buffer2, buffer_size);

      for(int i = 0; i < counter2; i++){
        char curr = buffer2[i];
        write(sock_fd2, &curr, 1);
      }

    }

    if(fds[1].revents & (POLLHUP | POLLERR)){
      close(pipe_cp[0]);
      quit_message();
      close(sock_fd2);
      close(sock_fd);
      exit(0);
    }



  }
}

void Parent_process_compress(){
  close(pipe_pc[0]);
  close(pipe_cp[1]);
  fds[0].fd = sock_fd2;
  fds[0].events = POLLIN | POLLHUP | POLLERR;

  fds[1].fd = pipe_cp[0];
  fds[1].events = POLLIN | POLLHUP | POLLERR;

  unsigned char buffer[buffer_size];
  unsigned char buffer_compress[buffer_size];

  int buffer_size_compress = 256;
  while(1){
    int factor = poll(fds, 2, 0);
    if(factor == -1){
      fprintf(stderr, "ERROR IN POLL(). \n");
      close(sock_fd2);
      close(sock_fd);
      exit(1);
    }

    if(fds[0].revents & POLLIN){
      int counter = read(sock_fd2, buffer, buffer_size);
      if(counter < 0){
        fprintf(stderr, "ERROR IN READ FROM SOCK2");
        kill(0, SIGTERM);
      }
if(counter > 0){
      strm1.zalloc = Z_NULL;
      strm1.zfree = Z_NULL;
      strm1.opaque = Z_NULL;

      if(inflateInit(&strm1) != Z_OK){
        fprintf(stderr, "ERROR IN Initialize DECOMPRESSION");
        exit(1);
      }

      strm1.avail_out = buffer_size_compress;
      strm1.next_out = buffer_compress;
      strm1.avail_in = counter;
      strm1.next_in = buffer;

      do{
        if(inflate(&strm1, Z_FULL_FLUSH) != Z_OK){
          fprintf(stderr, "ERROR IN DEFLATIG");
          exit(1);
        }
      }while(strm1.avail_in >0);

      inflateEnd(&strm1);
      int size = buffer_size_compress - strm1.avail_out;
      for(int i = 0; i < size; i++){
        char curr = buffer_compress[i];
        if(curr == 0X0A || curr == 0X0D){
          char temp = 0X0A;
          write(pipe_pc[1], &temp, 1 );
        }
        else if(curr == 0X04){
          close(pipe_pc[1]);
        }
        else if(curr == 0X03){
          kill(cpid, SIGINT);
        }
        else{
          write(pipe_pc[1], &curr, 1);
        }}
      }
    }

    if(fds[1].revents & POLLIN){
      int counter = read(pipe_cp[0], buffer, buffer_size);
      if(counter < 0){
        fprintf(stderr, "ERROR IN READ FROM SOCK2");
        kill(0, SIGTERM);
      }

      if(counter == 0){
        continue;
      }

      strm2.zalloc = Z_NULL;
      strm2.zfree = Z_NULL;
      strm2.opaque = Z_NULL;

      if(deflateInit(&strm2, Z_DEFAULT_COMPRESSION) != Z_OK){
        fprintf(stderr, "ERROR IN Initialize COMPRESSION");
        close(sock_fd);
        close(sock_fd2);
        exit(1);
      }

      strm2.avail_out = buffer_size_compress;
      strm2.next_out = buffer_compress;
      strm2.avail_in = counter;
      strm2.next_in = buffer;

      do{
        if(deflate(&strm2, Z_FULL_FLUSH) != Z_OK){
          fprintf(stderr, "ERROR IN DEFLATIG");
          exit(1);
        }
      }while(strm2.avail_in >0);

      int size = buffer_size_compress - strm2.avail_out;
      write(sock_fd2, buffer_compress, size);
      deflateEnd(&strm2);
    }

    if(fds[1].revents & (POLLHUP | POLLERR)){
      close(pipe_cp[0]);
      quit_message();
      close(sock_fd2);
      close(sock_fd);
      exit(0);
    }
  }
}

int main(int argc, char** argv){
  struct option long_option[] = {
    {"port", required_argument, 0, 1},
    {"compress", no_argument, 0, 2},
    {0, 0, 0, 0}
  };

  int option;
  int long_index;
  while((option = getopt_long(argc, argv, "", long_option, &long_index)) != -1){
    switch (option) {
      case 1:
        port_index = atoi(optarg);
        port_command = 1;
        break;
      case 2:
        compress_command = 1;
        break;
      default:
        fprintf(stderr, "INVALID COMMAND" );
        exit(1);
    }
  }

  if(port_command != 1){
    fprintf(stderr, "PLEASE PORT COMMAND TO CONSTUCT THE SERVER" );
    exit(1);
  }

  struct sockaddr_in server_address, client_address;
  unsigned int client_length;

  sock_fd = socket(AF_INET, SOCK_STREAM, 0);
  if(sock_fd < 0){
    fprintf(stderr, "ERROR IN NEW SOCKING");
    exit(1);
  }

  memset((char *) &server_address, 0, sizeof(server_address));
  server_address.sin_family = AF_INET;
  server_address.sin_addr.s_addr = INADDR_ANY;
  server_address.sin_port = htons(port_index);

  if(bind(sock_fd, (struct sockaddr *)&server_address, sizeof(server_address)) < 0){
    fprintf(stderr, "ERROR IN BINDING");
    exit(1);
  }

  listen(sock_fd, 5);
  client_length = sizeof(client_address);

  sock_fd2 = accept(sock_fd, (struct sockaddr*)&client_address, &client_length);
  if(sock_fd2 < 0){
    fprintf(stderr, "ERROR IN ACCEPT CLIENT SOCK");
    close(sock_fd2);
    close(sock_fd);
    exit(1);
  }

  if(pipe(pipe_pc) == -1){
    fprintf(stderr, "Pipe error for parent to child : %s", strerror(errno));
    close(sock_fd2);
    close(sock_fd);
    exit(1);
  }
  if(pipe(pipe_cp) == -1){
    fprintf(stderr, "Pipe error for child to Parent : %s ", strerror(errno));
    exit(1);
  }

  cpid = fork();

  if(cpid < 0){
    fprintf(stderr, "Fork() is failed");
    close(sock_fd2);
    close(sock_fd);
    exit(1);
  }
  if(cpid > 0){
    if(!compress_command){Parent_process();}
    if(compress_command){Parent_process_compress();}
  }
  if(cpid == 0 ){
    Child_process();
  }



}
