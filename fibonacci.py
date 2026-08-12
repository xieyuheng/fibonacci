def fibonacci(n):
    if n <= 1:
        return n
    else:
        return fibonacci(n - 1) + fibonacci(n - 2)


def main():
    print(fibonacci(10))
    print(fibonacci(20))
    print(fibonacci(30))
    print(fibonacci(35))
    print(fibonacci(40))

if __name__ == "__main__":
    main()
