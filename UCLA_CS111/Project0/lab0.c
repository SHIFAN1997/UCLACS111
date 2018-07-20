//NAME : Fan Shi
//EMAIL : fanshi2@g.ucla.edu

#include <stdlib.h>
#include <stdio.h>
#include <getopt.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>                 // use for read() and write()
#include <string.h>

void signal_handler(int singal){
  fprintf(stderr, "Segmentation fault caught by --catch option. \n");
  exit(4);
}

int main(int argc, char **argv){
  struct option long_option[] = {
    {"input", required_argument, 0, 1},
    {"output", required_argument, 0, 2},
    {"segfault", no_argument, 0, 3},
    {"catch", no_argument, 0, 4},
    {0, 0, 0, 0}
  };

  char *input_file = NULL;
  char *output_file = NULL;

  int input_flag = 0;
  int output_flag = 0;
  int segfault_flag = 0;
  int catch_flag = 0;
  int option;
  while(1){
    option = getopt_long(argc, argv, "", long_option, 0);
    if(option == -1){
      break;
    }

    switch(option){
      case 1:
        input_flag = 1;
        input_file = optarg;
        break;
      case 2:
        output_flag = 1;
        output_file = optarg;
        break;
      case 3:
        segfault_flag = 1;
        break;
      case 4:
        catch_flag = 1;
        break;

      default:
        printf("unrecognized command, lab0 --input filename --output filename [sc] \n ");
        exit(1);
    }
  }

  if(catch_flag){
    signal(SIGSEGV, signal_handler);
  }

  if(segfault_flag){
    char *ptr = NULL;
    *ptr = 'P';
  }

  if(input_flag){                    //open file
    int in_fd = open(input_file, O_RDONLY);
    if(in_fd >= 0){
      close(0);
      dup(in_fd);
      close(in_fd);
    }
    else{
      //printf("get there 2");
      fprintf(stderr, "error in input: %s", strerror(errno));
      exit(2);
    }
  }

  if(output_flag){                  //create file to be written
    int out_fd = creat(output_file, 0666);
    if(out_fd >= 0){
      close(1);
      dup(out_fd);
      close(out_fd);
    }

    else{
      //printf("get there 3");
      fprintf(stderr, "error in output: %s\n", strerror(errno));
      exit(3);
    }
  }

  char *buffer = malloc(sizeof(char));

  while(read(0, buffer, 1) > 0){
    int write_size = write(1, buffer, 1);
    if(write_size != 1){
      fprintf(stderr, "error in copy out the message: %s\n", strerror(errno));
      exit(3);
    }
  }

  exit(0);

}
