package main

import "fmt"

func fibonacci(n int64) int64 {
  if n <= 1 {
    return n
  } else {
    return fibonacci(n-1) + fibonacci(n-2)
  }
}

func main() {
  fmt.Println(fibonacci(10))
  fmt.Println(fibonacci(20))
  fmt.Println(fibonacci(30))
  fmt.Println(fibonacci(35))
  fmt.Println(fibonacci(40))
}