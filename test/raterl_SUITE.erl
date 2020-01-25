%% -------------------------------------------------------------------
%%
%% Copyright (c) 2016 Luis Rascão.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(raterl_SUITE).
-compile([export_all]).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

%% -------------------------------------------------------------
%% Callback Functions
%% -------------------------------------------------------------

all() ->
    [{group, Group} || Group <- [rate, counter]].

groups() ->
    [{rate, [],
        [low_rate, close_rate, exceeded_rate, queue_reconfiguration]
     },
     {counter, [],
        [low_count, close_count, exceeded_count, monitored_count, queue_reconfiguration]
     }].

init_per_suite(Config) ->
    SuiteConfig = ct:get_config(config),
    DataDir = lookup_config(data_dir, Config),
    log("suite config: ~p\n", [SuiteConfig]),
    log("data dir: ~p\n", [DataDir]),
    application:ensure_all_started(raterl),
    Config.

end_per_suite(Config) ->
    Config.

init_per_group(GroupName, Config) ->
    % ct:print(default, 50, "starting test group: ~p", [GroupName]),
    [{regulator_type, GroupName} | Config].

end_per_group(_GroupName, Config) ->
    % ct:print(default, 50, "ending test group: ~p", [GroupName]),
    Config.

%% included for test server compatibility
%% assume that all test cases only takes Config as sole argument
init_per_testcase(_Func, Config) ->
    global:register_name(raterl_global_logger, group_leader()),
    Config.

end_per_testcase(_Func, Config) ->
    global:unregister_name(raterl_global_logger),
    %% wait a full second so as not to burn out the rate
    timer:sleep(1000),
    Config.

%% -------------------------------------------------------------
%% Test Cases
%% -------------------------------------------------------------

low_rate(doc) -> ["Low rate"];
low_rate(suite) -> [];
low_rate(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({low_rate,
                                [{regulator,
                                  [{name, rate},
                                   {type, rate},
                                   {limit, 10}]}]}),
    %% the info request here is to ensure that
    %% the queue has been initialized before making
    %% any requests to it
    % _ = raterl:info(low_rate),
    ?assertMatch([ok,ok,ok,ok,ok],
                 [raterl:run(low_rate, {rate, rate}, fun() -> ok end)
                    || _ <- lists:seq(1, 5)]),
    ok = raterl_queue:stop(low_rate).

close_rate(doc) -> ["Close rate"];
close_rate(suite) -> [];
close_rate(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({close_rate,
                                [{regulator,
                                  [{name, rate},
                                   {type, rate},
                                   {limit, 10}]}]}),
    %% the info request here is to ensure that
    %% the queue has been initialized before making
    %% any requests to it
    _ = raterl:info(close_rate),
    ?assertMatch([ok,ok,ok,ok,ok,ok,ok,ok,ok,ok],
                 [raterl:run(close_rate, {rate, rate}, fun() -> ok end)
                    || _ <- lists:seq(1, 10)]),
    ok = raterl_queue:stop(close_rate).

exceeded_rate(doc) -> ["Close rate"];
exceeded_rate(suite) -> [];
exceeded_rate(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({exceeded_rate,
                                [{regulator,
                                  [{name, rate},
                                   {type, rate},
                                   {limit, 10}]}]}),
    %% the info request here is to ensure that
    %% the queue has been initialized before making
    %% any requests to it
    _ = raterl:info(exceeded_rate),
    ?assertMatch([ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,limit_reached],
                 [raterl:run(exceeded_rate, {rate, rate}, fun() -> ok end)
                   || _ <- lists:seq(1, 11)]),
    ok = raterl_queue:stop(exceeded_rate).

low_count(doc) -> ["Low count"];
low_count(suite) -> [];
low_count(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({low_counter,
                                [{regulator,
                                  [{name, counter},
                                   {type, counter},
                                   {limit, 10}]}]}),
    try
        ?assertEqual([ok,ok,ok,ok,ok],
                     raterl_run_nested(low_counter, {counter, counter}, 5))
    after
        _ = raterl_queue:stop(low_counter)
    end.

close_count(doc) -> ["Close count"];
close_count(suite) -> [];
close_count(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({close_counter,
                                [{regulator,
                                  [{name, counter},
                                   {type, counter},
                                   {limit, 10}]}]}),
    try
        ?assertEqual([ok,ok,ok,ok,ok,ok,ok,ok,ok,ok],
                     raterl_run_nested(close_counter, {counter, counter}, 10))
    after
        _ = raterl_queue:stop(close_counter)
    end.

exceeded_count(doc) -> ["Exceeded count"];
exceeded_count(suite) -> [];
exceeded_count(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({exceeded_counter,
                                [{regulator,
                                  [{name, counter},
                                   {type, counter},
                                   {limit, 10}]}]}),
    try
        ?assertEqual([ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,limit_reached],
                     raterl_run_nested(exceeded_counter, {counter, counter}, 11)),
        ?assertEqual([ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,limit_reached],
                     raterl_run_nested(exceeded_counter, {counter, counter}, 12)),
        ?assertEqual([ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,limit_reached],
                     raterl_run_nested(exceeded_counter, {counter, counter}, 100))
    after
        _ = raterl_queue:stop(exceeded_counter)
    end.

monitored_count(doc) -> ["Monitored count"];
monitored_count(suite) -> [];
monitored_count(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({monitored_counter,
                                [{regulator,
                                  [{name, counter},
                                   {type, counter},
                                   {limit, 3}]}]}),
    RunGen =
        fun (UnblockKey) ->
                fun () ->
                        raterl:run(monitored_counter, {counter, counter},
                                   fun () -> block(UnblockKey) end)
                end
        end,
    HardRun = RunGen(make_ref()),
    SoftRun = RunGen(goodbye),
    CallerTrapExit = process_flag(trap_exit, true),

    try
        Pids = [spawn_link(HardRun) || _ <- lists:seq(1, 4)],
        timer:sleep(10),
        ?assertEqual([false, true, true, true],
                     lists:sort([is_process_alive(Pid) || Pid <- Pids])),
        _ = self() ! goodbye,
        ?assertEqual(limit_reached, SoftRun()),

        _ = [exit(Pid, kill) || Pid <- Pids],
        timer:sleep(10),
        ?assertEqual([false, false, false, false],
                     [is_process_alive(Pid) || Pid <- Pids]),
        ?assertEqual(ok, SoftRun())
    after
        _ = process_flag(trap_exit, CallerTrapExit),
        _ = raterl_queue:stop(monitored_counter)
    end.

queue_reconfiguration(doc) -> ["Add/remove queues in runtime"];
queue_reconfiguration(suite) -> [];
queue_reconfiguration(Config) when is_list(Config) ->
    {_, NameAndType} = lists:keyfind(regulator_type, 1, Config),
    QueueOptsA = [{regulator, [{name,NameAndType}, {type,NameAndType}, {limit,10}]}],
    QueueOptsB = [{regulator, [{name,NameAndType}, {type,NameAndType}, {limit,20}]}],

    % we start with no queues
    NoChildren = supervisor:which_children(raterl_queue_sup),
    ?assertEqual([], NoChildren),

    % we add one queue
    ok = raterl:reconfigure_queues([{foo, QueueOptsA}]),
    OneChild = supervisor:which_children(raterl_queue_sup),
    ?assertMatch([_], OneChild),
    ?assertNotEqual(undefined, whereis(raterl_utils:queue_name(foo))),

    % we add one queue and remove the other
    ok = raterl:reconfigure_queues([{bar, QueueOptsA}]),
    AnotherChild = supervisor:which_children(raterl_queue_sup),
    ?assertMatch([_], AnotherChild),
    [{_, BarPid1, _, _}] = AnotherChild,
    ?assertEqual(undefined, whereis(raterl_utils:queue_name(foo))),
    ?assertNotEqual(undefined, whereis(raterl_utils:queue_name(bar))),

    % we reconfigure a queue with same options and nothing happens
    ok = raterl:reconfigure_queues([{bar, QueueOptsA}]),
    YetAnotherChild = supervisor:which_children(raterl_queue_sup),
    ?assertMatch([_], YetAnotherChild),
    [{_, BarPid2, _, _}] = YetAnotherChild,
    ?assertEqual(BarPid2, BarPid1),

    % we reconfigure a queue with a different options and it gets recreated
    ok = raterl:reconfigure_queues([{bar, QueueOptsB}]),
    SurelyADifferentChild = supervisor:which_children(raterl_queue_sup),
    ?assertMatch([_], SurelyADifferentChild),
    [{_, BarPid3, _, _}] = SurelyADifferentChild,
    ?assertNotEqual(BarPid3, BarPid2),

    % we remove the queue and end up with none
    ok = raterl:reconfigure_queues([]),
    NoChildren = supervisor:which_children(raterl_queue_sup),
    ?assertEqual([], NoChildren).

%% -------------------------------------------------------------
%% Private methods
%% -------------------------------------------------------------

lookup_config(Key,Config) ->
    case lists:keysearch(Key,1,Config) of
    {value,{Key,Val}} ->
        Val;
    _ ->
        []
    end.

log(Format, Args) ->
    case global:whereis_name(raterl_global_logger) of
        undefined ->
            io:format(user, Format, Args);
        Pid ->
            io:format(Pid, Format, Args)
    end.

raterl_run_nested(Name, RegTypeAndName, Depth) ->
    raterl_run_nested_recur(Name, RegTypeAndName, Depth, []).

raterl_run_nested_recur(_Name, _RegTypeAndName, Depth, Acc)
  when Depth =:= 0 ->
    lists:reverse(Acc);
raterl_run_nested_recur(Name, RegTypeAndName, Depth, Acc)
  when Depth > 0 ->
    case raterl:run(
           Name, RegTypeAndName,
           fun () -> raterl_run_nested_recur(Name, RegTypeAndName, Depth - 1, [ok | Acc]) end)
    of
        limit_reached ->
            lists:reverse([limit_reached | Acc]);
        ReturnValue ->
            ReturnValue
    end.

block(UnblockKey) ->
    receive UnblockKey -> ok end.
