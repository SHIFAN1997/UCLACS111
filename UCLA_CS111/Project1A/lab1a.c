// NAME : Fan Shi
// EMAIL : fanshi2@g.ucla.edu
//ID: 805256911

#include <stdlib.h>
#include <stdio.h>
#include <getopt.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <termio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <poll.h>
#include <errno.h>

#define buffer_size 1024

int shell_command = 0;
int pipe_pc[2];           //pipe for Parent to Child
int pipe_cp[2];           //pipe for Child to parent
pid_t cpid;
struct pollfd fds[2];
struct termios saved_attributes;

void reset_input_mode(){
  tcsetattr(STDIN_FILENO, TCSANOW, &saved_attributes);
}

void reset_input_mode_shell(){
  tcsetattr(STDIN_FILENO, TCSANOW, &saved_attributes);
  int status = 0;
  waitpid(0, &status, 0);
  fprintf(stderr, "SHELL EXIT SIGNAL=%d STATUS=%d\n", WTERMSIG(status), WEXITSTATUS(status));
}

void interrupt_handler(int sig){
  if(sig == SIGPIPE){
    reset_input_mode_shell();
    exit(0);
  }
}
void read_write_default(int read_fd, int write_fd){
  char *buffer = malloc(sizeof(char) * ( buffer_size ));
  ssize_t counter = 0;
  char curr;
  while(1){
    counter = read(read_fd, buffer, buffer_size);
    for(unsigned int i = 0; i < counter; i++){
      curr = buffer[i];
      if(curr == 0X0D || curr == 0X0A){
        char temp[2] = {0X0D, 0X0A};
        write(write_fd, temp, 2);
      }
      else if(curr == 0X04){
        free(buffer);
        reset_input_mode();
        exit(0);
      }

      else{
        write(write_fd, buffer+i, 1);
      }
    }
  }

}

void parent_process(){
  close(pipe_pc[0]);
  close(pipe_cp[1]);
  fds[0].fd = 0;
  fds[0].events = POLLIN | POLLHUP | POLLERR;

  fds[1].fd = pipe_cp[0];
  fds[1].events = POLLIN | POLLHUP | POLLERR;
  while(1){
    int factor = poll(fds, 2, 0);
    if(factor == -1){
      fprintf(stderr, "Poll() failure : %s", strerror(errno));
      reset_input_mode_shell();
      exit(1);
    }

    if(fds[0].revents & (POLLHUP + POLLERR)){
      fprintf(stderr, "Failure in shell : %s", strerror(errno));
      break;
    }

    if(fds[0].revents & POLLIN){
      char buffer[buffer_size];
      ssize_t counter = 0;
      counter = read(0, buffer, buffer_size);
      for(unsigned int i = 0; i < counter; i++){
        char curr = buffer[i];
        if(curr == 0X04){
          close(pipe_pc[1]);
        }
        else if(curr == 0X0D || curr == 0X0A){
          char temp1[1] = {0X0A};
          write(pipe_pc[1], temp1, 1);
          char temp2[2] = {0X0D, 0X0A};
          write(STDOUT_FILENO, temp2, 2);
        }
        else if(curr == 0X03){
          kill(cpid, SIGINT);
        }
        else{
          write(STDOUT_FILENO, buffer + i, 1);
          write(pipe_pc[1], buffer + i, 1);
        }
      }
    }

    if(fds[1].revents & POLLIN){
      char buffer[buffer_size];
      ssize_t counter = 0;
      counter = read(pipe_cp[0], buffer, buffer_size);
      for(unsigned int i = 0; i < counter; i++){
        char curr = buffer[i];
        if(curr == 0X0A){
          char temp[2] = {0X0D, 0X0A};
          write(STDOUT_FILENO, temp, 2);
        }
        else if(curr == 0X04){
          reset_input_mode_shell();
          exit(0);
        }
        else{
          write(STDOUT_FILENO, buffer + i, 1);
        }
      }
    }

    if(fds[1].revents & (POLLERR | POLLHUP)){
      //close all pipe
      close(pipe_pc[1]);
      reset_input_mode_shell();
      exit(0);
    }
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
    exit(1);
  }
}

int main(int argc, char **argv){
  struct option long_option[] = {
    {"shell", no_argument, 0, 's'},
    {0,  0,  0,  0}
  };

  int option;
  while((option = getopt_long(argc, argv, "", long_option, 0)) != -1){
    switch(option){
      case 's':
        shell_command = 1;
        //signal(SIGINT, interrupt_handler);
        //signal(SIGPIPE, interrupt_handler);
        break;
      default:
        printf("invalid command, please use ./lab1a or ./lab1a --shell");
        exit(1);
        break;
    }
  }
  //printf("get here");
  /*
  Folllow code use the source from https://www.gnu.org/software/libc/manual/html_node/Noncanon-Example.html

  */
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

  //new_attributes.c_lflag &= ~(ICANON|ECHO);
  //new_attributes.c_cc[VMIN] = 1;
  //new_attributes.c_cc[VTIME] = 0;
  /*reference end here*/

  //tcsetattr(STDIN_FILENO, TCSAFLUSH, &new_attributes);
  if(tcsetattr(STDIN_FILENO, TCSANOW, &new_attributes) < 0){
    fprintf(stderr, "Failure : %s", strerror(errno));
    exit(EXIT_FAILURE);
  }
  if(!shell_command){
    read_write_default(0, STDIN_FILENO);
  }

  /*following code use the idea presented by
  http://man7.org/linux/man-pages/man2/pipe.2.html
  */
  //signal(SIGPIPE, interrupt_handler);

  if(pipe(pipe_pc) == -1){
    fprintf(stderr, "Pipe error for parent to child : %s", strerror(errno));
    exit(1);
  }
  if(pipe(pipe_cp) == -1){
    fprintf(stderr, "Pipe error for child to Parent : %s ", strerror(errno));
    exit(1);
  }

  cpid = fork();
  if(cpid < 0){
    fprintf(stderr, "Fork() is failed");
    exit(1);
  }
  if(cpid > 0){
    parent_process();
  }
  if(cpid == 0 ){
    Child_process();
  }

  reset_input_mode_shell();
  exit(0);
}
