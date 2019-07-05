-module(mybench_SUITE).

-include_lib("common_test/include/ct.hrl").
-compile(export_all).

all() ->
    [test_run, test_batch, test_base, test_parallel].

test_run(_Config) ->
    mybench:run(#{f => fun () -> ok end}, 1000).

test_batch(_Config) ->
    mybench:run(#{f => fun () -> ok end}, 100, #{batch => 1}).

test_base(_Config) ->
    mybench:run(#{f => fun () -> ok end}, 100, #{base => {fun () -> ok end, fun () -> ok end}, batch => 1}).

test_parallel(_Config) ->
    mybench:run(#{f => fun () -> ok end}, 100, #{batch => 1, parallel => 1}).
