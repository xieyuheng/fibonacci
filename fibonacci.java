// javac fibonacci.java
// time java fibonacci

public class fibonacci {
  public static int fibonacci(int n) {
    if (n <= 1) {
      return n;
    } else {
      return fibonacci(n - 1) + fibonacci(n - 2);
    }
  }

  public static void main(String[] args) {
    System.out.println(fibonacci(10));
    System.out.println(fibonacci(20));
    System.out.println(fibonacci(30));
    System.out.println(fibonacci(35));
  }
}
