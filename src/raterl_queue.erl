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
         stop/1]).

%% Gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

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
                   regulator = Regulator0,
                   timer_ref = TimerRef0} = State0) ->
    Regulator = lists:keyreplace(limit, 1, Regulator0,
                                 {limit, Limit}),
    Table = raterl_utils:table_name(Name),
    %% if this is a rate regulator then we need to
    %% cancel the refresh timer and start another with
    %% the new limit
    State =
        case proplists:get_value(type, Regulator) of
            rate ->
                erlang:cancel_timer(TimerRef0),
                TimerRef = erlang:send_after(1000, self(),
                                    {refresh_rate_limit, Table, RegName, Limit + 1}),
                State0#state{regulator = Regulator,
                             timer_ref = TimerRef};
            _ ->
                State0#state{regulator = Regulator}
        end,
    %% in either case we update the counter to the new limit
    true = ets:update_element(Table, RegName, {2, Limit}), 
    {reply, ok, State};
handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_cast(stop, State) ->
    {stop, normal, State};
handle_cast(_, State) ->
    {noreply, State}.

handle_info({refresh_rate_limit, Table, Name, Limit}, State) ->
    %% update the ets counter with the configured rate limit 
    true = ets:update_element(Table, Name, {2, Limit}),
    TimerRef = erlang:send_after(1000, self(),
                                {refresh_rate_limit, Table, Name, Limit}),
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
    %% initialize the counter to limit+1 since
    %% we'll be rate limiting at zero instead of
    %% at negative 1 
    erlang:send_after(1000, self(),
                      {refresh_rate_limit, Table, Name, Limit + 1});
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

