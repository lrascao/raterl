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
%%%-------------------------------------------------------------------
%% @doc raterl queue.
%% @end
%%%-------------------------------------------------------------------

-module(raterl_queue).

-behaviour(gen_server).

%% API
-export([start_link/1,
         new/1,
         info/1,
         modify_regulator/3,
         cancel_timer/1,
         restart_timer/1,
         stop/1]).

%% Gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).
-define(REFRESH_TIMEOUT, 1000).

-record(state, {
          name :: atom(),
          regulator :: proplists:proplist(),
          timer_ref :: reference()
         }).

%%====================================================================
%% API functions
%%====================================================================

start_link({Name, Opts}) ->
    RegName = raterl_utils:queue_name(Name), 
    gen_server:start_link({local, RegName}, ?MODULE, [{Name, Opts}], []).

new(Args) ->
    supervisor:start_child(raterl_queue_sup, [Args]).

stop(Name) ->
    ok = gen_server:cast(raterl_utils:queue_name(Name),
                         stop).
info(Name) ->
    gen_server:call(raterl_utils:queue_name(Name),
                    info).

modify_regulator(Name, RegName, Limit) ->
    gen_server:call(raterl_utils:queue_name(Name),
                    {modify_regulator, RegName, Limit}).

cancel_timer(Name) ->
    gen_server:call(raterl_utils:queue_name(Name), cancel_timer).

restart_timer(Name) ->
    gen_server:cast(raterl_utils:queue_name(Name), restart_timer).

%%====================================================================
%% Gen_server callbacks
%%====================================================================

init([{Name, Opts}]) ->
    Regulator = proplists:get_value(regulator,
                                     Opts),
    TimerRef = init_regulator(Name, Regulator),
    {ok, #state{name = Name,
                regulator = Regulator,
                timer_ref = TimerRef}}.

handle_call(info, _From, State) ->
    {reply, State, State};
handle_call({modify_regulator, RegName, Limit}, _From,
            #state{name = Name,
                   regulator = Regulator0} = State0) ->
    Table = raterl_utils:table_name(Name),
    %% we update the counter to the new limit immediately!
    true = ets:update_element(Table, RegName, {2, Limit}),

    Regulator = lists:keyreplace(limit, 1, Regulator0,
                                 {limit, Limit}),
    State = State0#state{regulator = Regulator},
    {reply, ok, State};
handle_call(cancel_timer, _From,
            #state{timer_ref = TimerRef} = State)
    when TimerRef =/= undefined ->
    Ret = erlang:cancel_timer(TimerRef),
    {reply, Ret, State#state{timer_ref = undefined}};
handle_call(_Msg, _From, State) ->
    {reply, error, State}.

handle_cast(stop, State) ->
    {stop, normal, State};
handle_cast(restart_timer, #state{name = QueueName,
                                  regulator = Regulator,
                                  timer_ref = undefined} = State) ->
    Table = raterl_utils:table_name(QueueName),
    Name = proplists:get_value(name, Regulator),
    TimerRef = set_refresh_timer(Table, Name),
    {noreply, State#state{timer_ref = TimerRef}};
handle_cast(restart_timer, #state{name = QueueName,
                                  timer_ref = TimerRef} = State)
    when TimerRef =/= undefined ->
    %% first cancel the timer and then cast to self to restart it!
    _ = erlang:cancel_timer(TimerRef),
    restart_timer(QueueName),
    {noreply, State#state{timer_ref = undefined}};
handle_cast(_, State) ->
    {noreply, State}.

handle_info({refresh_rate_limit, Table, Name},
            #state{regulator = Regulator} = State) ->
    %% if this is a rate regulator then we need to
    %% update the limit and start another timer
    TimerRef = case proplists:get_value(type, Regulator) of
                   rate ->
                       %% update the ets counter with the configured rate
                       %% to limit+1 since we'll be rate limiting at zero
                       %% instead of at negative 1
                       Limit = proplists:get_value(limit, Regulator),
                       true = ets:update_element(Table, Name, {2, Limit + 1}),
                       set_refresh_timer(Table, Name);
                   _ ->
                       undefined
               end,
    {noreply, State#state{timer_ref = TimerRef}};
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal functions
%%====================================================================

init_regulator(QueueName, Opts) ->
    Name = proplists:get_value(name, Opts),
    Type = proplists:get_value(type, Opts),
    %% save the queue configuration in ets so
    %% it's easily reached by every client
    ets:insert_new(raterl, {QueueName, Type, Name}),
    init_regulator(QueueName, Type, Name, Opts).

init_regulator(QueueName, rate, Name, Opts) ->
    Limit = proplists:get_value(limit, Opts),
    %% create the ets counter that will hold
    %% the limit
    Table = raterl_utils:table_name(QueueName),
    ets:new(Table,
            [public, set, named_table,
             {write_concurrency, true}]),
    ets:insert_new(Table, {Name, Limit + 1}),
    %% set a up a recurrent timer that sets the rate
    %% counter to the limit on every second
    set_refresh_timer(Table, Name);
init_regulator(QueueName, counter, Name, Opts) ->
    Limit = proplists:get_value(limit, Opts),
    %% create the ets counter that will hold
    %% the limit
    Table = raterl_utils:table_name(QueueName),
    ets:new(Table,
            [public, set, named_table,
             {write_concurrency, true}]),
    ets:insert_new(Table, {Name, Limit + 1}),
    undefined.

set_refresh_timer(Table, Name) ->
    erlang:send_after(?REFRESH_TIMEOUT, self(),
                      {refresh_rate_limit, Table, Name}).
