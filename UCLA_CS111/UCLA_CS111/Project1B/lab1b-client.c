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

#include <netinet/in.h>
#include <string.h>
#include <zlib.h>
#define buffer_size 256

int port_command = 0;
int log_command = 0;
int compress_command = 0;
int port_index;
char *log_file = NULL;

int log_fd;
int sock_fd;
struct termios saved_attributes;
char crlf[2] = {0X0D, 0X0A};

z_stream strm1;
z_stream strm2;

void reset_input_mode(){
  tcsetattr(STDIN_FILENO, TCSANOW, &saved_attributes);
  if(log_command){
    close(log_fd);
  }

  close(sock_fd);
}

void write_send_log(char curr){
  char temp = '\n';
  char temp_string[14] = "SENT 1 bytes: ";
  write(log_fd, &temp_string, 14);
  write(log_fd, &curr, 1);
  write(log_fd, &temp, 1);
}

void write_receive_log(char curr){
  char temp = '\n';
  char temp_string[18] = "RECEIVED 1 bytes: ";
  write(log_fd, &temp_string, 18);
  write(log_fd, &curr, 1);
  write(log_fd, &temp, 1);
}

void write_process_default(){
  struct pollfd fds[2];
  fds[0].fd = STDIN_FILENO;
  fds[0].events = POLLIN | POLLHUP | POLLERR;

  fds[1].fd = sock_fd;
  fds[1].events = POLLIN | POLLHUP | POLLERR;

  char buffer[buffer_size];
  char buffer2[buffer_size];
  while(1){
    int factor = poll(fds, 2, 0);
    if(factor == -1){
      fprintf(stderr, "Poll() failure : %s", strerror(errno));
      reset_input_mode();
      exit(1);
    }

    if(fds[0].revents & POLLIN){
      int counter = read(0, buffer, buffer_size);
      if(counter < 0){
        fprintf(stderr, "FAILURE IN READING FROM KEYBOARD");
        reset_input_mode();
        exit(1);
      }
      for(int i = 0; i < counter; i++){
        char curr = buffer[i];
        if(curr == 0X0A || curr == 0X0D){
          write(STDOUT_FILENO, &crlf, 2);
          write(sock_fd, &curr, 1);
          if(log_command){
            write_send_log(curr);
          }
        }
        else{
          write(STDIN_FILENO, &curr, 1);
          write(sock_fd, &curr, 1);
          if(log_command){
            write_send_log(curr);
          }
        }
      }
    }

    if(fds[0].revents &(POLLERR | POLLHUP)){
      fprintf(stderr, "ERROR IN SHELL");
      reset_input_mode();
      exit(0);
    }

    if(fds[1].revents & POLLIN){
      int counter = read(sock_fd, buffer2, buffer_size);
      if(counter < 0){
        fprintf(stderr, "READ FROM SOCKET FAILURE");
        reset_input_mode();
        exit(1);
      }

      if(counter == 0){
        reset_input_mode();
        exit(0);
      }
      for(int i = 0; i < counter; i++){
        char curr = buffer2[i];
        if(curr == 0x0A || curr == 0X0D){
          write(STDOUT_FILENO, &crlf, 2);
        }
        else{
          write(STDOUT_FILENO, &curr, 1);
        }

        if(log_command){
          write_receive_log(curr);
        }
      }
    }

    if(fds[1].revents & (POLLERR | POLLHUP)){
      //fprintf(stderr, "ERROR IN SHELL");
      reset_input_mode();
      exit(0);
    }
  }
}

void write_process_compress(){
  struct pollfd fds[2];
  fds[0].fd = 0;
  fds[0].events = POLLIN | POLLHUP | POLLERR;

  fds[1].fd = sock_fd;
  fds[1].events = POLLIN | POLLHUP | POLLERR;

  unsigned char buffer[buffer_size];
  unsigned char buffer_compress[buffer_size];

  const int buffer_size_compress = 256;
  while(1){
    int factor = poll(fds, 2, 0);
    if(factor == -1){
      fprintf(stderr, "Poll() failure : %s", strerror(errno));
      reset_input_mode();
      exit(1);
    }
    if(fds[0].revents &(POLLERR | POLLHUP)){
      fprintf(stderr, "ERROR IN SHELL");
      reset_input_mode();
      exit(0);
    }

    if((fds[0].revents & POLLIN)){
      int counter = read(0, buffer, buffer_size);
      if(counter < 0){
        fprintf(stderr, "ERROR IN READ FROM KEYBOARD. \n");
        reset_input_mode();
        exit(1);
      }
      if(counter > 0){
      strm1.zalloc = Z_NULL;
      strm1.zfree = Z_NULL;
      strm1.opaque = Z_NULL;

      if(deflateInit(&strm1, Z_DEFAULT_COMPRESSION) != Z_OK){
        fprintf(stderr, "ERROR IN Initialize COMPRESSION");
        reset_input_mode();
        exit(1);
      }

      strm1.avail_out = buffer_size_compress;
      strm1.next_out = buffer_compress;
      strm1.avail_in = counter;
      strm1.next_in = buffer;

      do{

        if(deflate(&strm1, Z_FULL_FLUSH) != Z_OK){
          fprintf(stderr, "ERROR IN DEFLATING");
          reset_input_mode();
          exit(1);
        }
      }while(strm1.avail_in > 0);

      write(sock_fd, &buffer_compress, buffer_size_compress - strm1.avail_out);
      if(log_command){
        int num = buffer_size_compress - strm1.avail_out;
        for(int k = 0; k < num; k++){
          write_send_log(buffer_compress[k]);
        }
      }
      deflateEnd(&strm1);
    }
      for(int i = 0; i < counter; i++){
        char curr = buffer[i];
        if(curr == 0X0A || curr == 0X0D){
          write(STDOUT_FILENO, &crlf, 2);
          if(log_command){
            write_send_log(curr);
          }
        }
        else{
          write(STDIN_FILENO, &curr, 1);
        }
      }
    }

    if(fds[1].revents & POLLIN){
      int counter = read(sock_fd, buffer, buffer_size);
      if(counter < 0){
        fprintf(stderr, "ERROR IN READ FROM KEYBOARD. \n");
        reset_input_mode();
        exit(1);
      }
      if(counter == 0){
        reset_input_mode();
        exit(0);
      }
      if(log_command){
        for(int k = 0; k<counter;k++){
          write_receive_log(buffer[k]);
        }
      }
      if(counter > 0){
      strm2.zalloc = Z_NULL;
      strm2.zfree = Z_NULL;
      strm2.opaque = Z_NULL;

      if(inflateInit(&strm2) != Z_OK){
        fprintf(stderr, "ERROR IN Initialize DECOMPRESSION");
        reset_input_mode();
        exit(1);
      }


      strm2.avail_out = buffer_size_compress;
      strm2.next_out = buffer_compress;
      strm2.avail_in = counter;
      strm2.next_in = buffer;

      do{
        if(inflate(&strm2, Z_FULL_FLUSH) != Z_OK){
          fprintf(stderr, "ERROR IN INFLATE2");
          reset_input_mode();
          exit(1);
        }
      }while(strm2.avail_in > 0);

      inflateEnd(&strm2);

      int size = buffer_size_compress - strm2.avail_out;
      for(int i = 0; i < size; i++){
        char curr = buffer_compress[i];
        if(curr == 0X0A || curr == 0X0D){
          write(STDOUT_FILENO, &crlf, 2);
        }
        else{
          write(STDOUT_FILENO, &curr, 1);
        }

        }
      }
    }

    if(fds[1].revents & (POLLERR | POLLHUP)){
      //fprintf(stderr, "ERROR IN SHELL");
      reset_input_mode();
      exit(0);
    }
  }
}

int main(int argc, char **argv){
  //printf("get here");
  struct option long_option[] = {
    {"port", required_argument, 0, 1},
    {"log", required_argument, 0, 2},
    {"compress", no_argument, 0, 3},
    {0, 0, 0, 0}
  };

  int option_index;
  int option;
  while((option = getopt_long(argc, argv, "", long_option, &option_index)) != -1){
    switch(option){
      case 1:
        port_index = atoi(optarg);
        port_command = 1;
        break;
      case 2:
        log_command = 1;
        log_file = optarg;
        log_fd = creat(log_file, S_IRWXU);

        if(log_fd < 0){
          fprintf(stderr, "ERROR IN CREATING LOG FILE: %s", strerror(errno));
          exit(1);
        }
        break;

      case 3:
        compress_command = 1;
        break;
        /*
        to be continued
        */

      default:
        fprintf(stderr, "INVALID COMMAND. \n");
        exit(1);
        break;

    }
  }

  struct sockaddr_in server_address;
  struct hostent *server;

  sock_fd = socket(AF_INET, SOCK_STREAM, 0);
  if(sock_fd < 0){
    fprintf(stderr, "ERROR IN CREATING SOCKET");
    exit(1);
  }

  server = gethostbyname("localhost");    //local host in IPV4
  if(server == NULL){
    fprintf(stderr, "NO HOST FOUND");
    exit(1);
  }

  memset((char*)&server_address, 0, sizeof(server_address));
  server_address.sin_family = AF_INET;
  memcpy((char*)&server_address.sin_addr.s_addr, (char*)server->h_addr, server->h_length);
  server_address.sin_port = htons(port_index);

  if(connect(sock_fd, (struct sockaddr*)&server_address, sizeof(server_address)) < 0){
    fprintf(stderr, "CONNECTING ERROR");
    exit(1);
  }

  //printf("get here");
  /*copy-paste from lab1a*/
  struct termios new_attributes;
  if(!isatty(STDIN_FILENO)){
    fprintf(stderr, "Not a terminal. \n");
    exit(EXIT_FAILURE);
  }
  //save termina attritube
  tcgetattr(STDIN_FILENO, &saved_attributes);
  atexit(reset_input_mode);

  new_attributes.c_iflag = ISTRIP;
  new_attributes.c_oflag = 0;
  new_attributes.c_lflag = 0;

  if(tcsetattr(STDIN_FILENO, TCSANOW, &new_attributes) < 0){
    fprintf(stderr, "Failure : %s", strerror(errno));
    exit(EXIT_FAILURE);
  }

  if(!compress_command){
    write_process_default();
  }

  else{
    write_process_compress();
  }


}
