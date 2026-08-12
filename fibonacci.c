#include <stdio.h>

// gcc -o fibonacci fibonacci.c
// time ./fibonacci

int fibonacci(int n) {
  if (n <= 1) {
    return n;
  } else {
    return fibonacci(n - 1) + fibonacci(n - 2);
  }
}

int main() {
  printf("%d\n", fibonacci(10));
  printf("%d\n", fibonacci(20));
  printf("%d\n", fibonacci(30));
  printf("%d\n", fibonacci(35));
  printf("%d\n", fibonacci(40));  
  return 0;
}
