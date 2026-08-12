-module(fibonacci).
-export([fibonacci/1, main/0]).

fibonacci(N) when N =< 1 ->
    N;
fibonacci(N) ->
    fibonacci(N - 1) + fibonacci(N - 2).

main() ->
    io:format("~p~n", [fibonacci(10)]),
    io:format("~p~n", [fibonacci(20)]),
    io:format("~p~n", [fibonacci(30)]),
    io:format("~p~n", [fibonacci(35)]),
    io:format("~p~n", [fibonacci(40)]).
