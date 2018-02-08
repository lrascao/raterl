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
    [{group, rate}].

groups() ->
    [{rate, [],
        [low_rate, close_rate, exceeded_rate, queue_reconfiguration]
     }].

init_per_suite(Config) ->
    SuiteConfig = ct:get_config(config),
    DataDir = lookup_config(data_dir, Config),
    log("suite config: ~p\n", [SuiteConfig]),
    log("data dir: ~p\n", [DataDir]),
    %% load an empty initial config
    application:set_env(raterl, queues, []),
    application:ensure_all_started(raterl),
    Config.

end_per_suite(Config) ->
    Config.

init_per_group(_GroupName, Config) ->
    % ct:print(default, 50, "starting test group: ~p", [GroupName]),
    Config.

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
    {ok, _} = raterl_queue:new({simple_rate,
                                [{regulator,
                                  [{name, rate},
                                   {type, rate},
                                   {limit, 10}]}]}),
    %% the info request here is to ensure that
    %% the queue has been initialized before making
    %% any requests to it
    % _ = raterl:info(simple_rate),
    ?assertMatch([ok,ok,ok,ok,ok],
                 [raterl:run(simple_rate, {rate, rate}, fun() -> ok end)
                    || _ <- lists:seq(1, 5)]),
    ok = raterl_queue:stop(simple_rate).

close_rate(doc) -> ["Close rate"];
close_rate(suite) -> [];
close_rate(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({simple_rate,
                                [{regulator,
                                  [{name, rate},
                                   {type, rate},
                                   {limit, 10}]}]}),
    %% the info request here is to ensure that
    %% the queue has been initialized before making
    %% any requests to it
    _ = raterl:info(simple_rate),
    ?assertMatch([ok,ok,ok,ok,ok,ok,ok,ok,ok,ok],
                 [raterl:run(simple_rate, {rate, rate}, fun() -> ok end)
                    || _ <- lists:seq(1, 10)]),
    ok = raterl_queue:stop(simple_rate).

exceeded_rate(doc) -> ["Close rate"];
exceeded_rate(suite) -> [];
exceeded_rate(Config) when is_list(Config) ->
    {ok, _} = raterl_queue:new({simple_rate,
                                [{regulator,
                                  [{name, rate},
                                   {type, rate},
                                   {limit, 10}]}]}),
    %% the info request here is to ensure that
    %% the queue has been initialized before making
    %% any requests to it
    _ = raterl:info(simple_rate),
    ?assertMatch([ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,limit_reached],
                 [raterl:run(simple_rate, {rate, rate}, fun() -> ok end)
                   || _ <- lists:seq(1, 11)]),
    ok = raterl_queue:stop(simple_rate).

queue_reconfiguration(doc) -> ["Add/remove queues in runtime"];
queue_reconfiguration(suite) -> [];
queue_reconfiguration(Config) when is_list(Config) ->
    QueueOptsA = [{regulator, [{name,rate}, {type,rate}, {limit,10}]}],
    QueueOptsB = [{regulator, [{name,rate}, {type,rate}, {limit,20}]}],

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

