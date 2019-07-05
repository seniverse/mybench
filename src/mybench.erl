-module(mybench).

-export([run/2, run/3]).

run(Bs, Time) ->
    run(Bs, Time, #{}).

run(Bs, Time, Options) when is_map(Bs) ->
    run(maps:to_list(Bs), Time, Options);
run(Bs,
    Time,
    #{batch := Batch,
      parallel := P,
      base := Base}) ->
    io:format("Running Base~n", []),
    BaseTime = bench(Base, Time, Batch, P),
    io:format("Base Time ~p~n", [BaseTime]),
    [begin
         io:format("Running Bench ~p~n", [Name]),
         BenchTime = bench(Bench, Time, Batch, P),
         io:format("Bench ~p Time ~p~n", [Name, BenchTime]),
         {Name, BenchTime - BaseTime}
     end
     || {Name, Bench} <- Bs];
run(Bs, Time, Options = #{parallel := P, base := Base}) ->
    run(Bs, Time, Options#{batch => find_value(fun (Batch) -> batch(Base, Batch, Time, P) end, 1)});
run(Bs, Time, Options = #{base := _}) ->
    run(Bs, Time, Options#{parallel => erlang:system_info(schedulers_online)});
run(Bs, Time, Options) ->
    run(Bs, Time, Options#{base => fun() -> ok end}).

find_value(Fun, Initial) ->
    find_value(Fun, 0.01, Initial).

find_value(Fun, Error, Initial) ->
    find_value(Fun, Error, Initial*2, Fun(Initial)).

find_value(Fun, Error, Value, Time) ->
    Time1 = Fun(Value),
    if abs(Time - Time1) / Time1 < Error ->
            Value;
       true ->
            find_value(Fun, Error, Value * 2, Time1)
    end.

batch(Base, Batch, Limit, P) ->
    io:format("Running batch ~b~n", [Batch]),
    Time = bench(Base, Limit, Batch, P),
    io:format("Batch ~b Time ~p~n", [Batch, Time]),
    Time.

bench({Fun, Init}, Time, Batch, Parallel) ->
    bench(Fun, Init, Time, Batch, Parallel);
bench(Fun, Time, Batch, Parallel) ->
    bench(Fun, fun () -> ok end, Time, Batch, Parallel).

bench(Fun, Init, Time, Batch, Parallel) ->
    Pids =
        [ begin
              Pid = spawn(fun() -> init(Fun, Init, Batch) end),
              erlang:trace(Pid, true, [call, monotonic_timestamp]),
              Pid ! start,
              Pid
          end
          || _ <- lists:seq(1, Parallel)],
    erlang:trace_pattern({?MODULE, benchee, 2}, true, [call_time]),
    receive
    after Time ->
            ok
    end,
    [exit(Pid, kill) || Pid <- Pids],
    erlang:trace_pattern({?MODULE, benchee, 2}, pause, [call_time]),
    {call_time, Times} = erlang:trace_info({?MODULE, benchee, 2}, call_time),
    lists:sum([S*1000000+US || {_, _, S, US} <- Times])/lists:sum([C || {_, C, _, _} <- Times])/Batch.

init(Fun, Init, Batch) ->
    Init(),
    tracee(Fun, Batch).

tracee(Fun, Batch) ->
    benchee(Fun, Batch),
    tracee(Fun, Batch).

benchee(Fun, Batch) ->
    loop(Fun, Batch).

loop(_, 0) ->
    ok;
loop(Fun, N) ->
    Fun(),
    loop(Fun, N-1).
