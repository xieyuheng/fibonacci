function fibonacci(n) {
  if (n <= 1) {
    return n
  } else {
    return fibonacci(n - 1) + fibonacci(n - 2)
  }
}

function main() {
  console.log(fibonacci(10))
  console.log(fibonacci(20))
  console.log(fibonacci(30))
  console.log(fibonacci(35))
  console.log(fibonacci(40))
}

main()
