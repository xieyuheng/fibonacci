def fibonacci(n)
  if n <= 1
    n
  else
    fibonacci(n - 1) + fibonacci(n - 2)
  end
end

def main
  puts fibonacci(10)
  puts fibonacci(20)
  puts fibonacci(30)
  puts fibonacci(35)
  puts fibonacci(40)  
end

main
