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
%% @doc raterl server.
%% @end
%%%-------------------------------------------------------------------

-module(raterl_server).

-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([reconfigure/1]).

%% Gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {queues}).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

reconfigure(Queues) ->
    gen_server:call(?SERVER, {reconfigure, Queues}, infinity).

%%====================================================================
%% Gen_server callbacks
%%====================================================================

init([]) ->
    Opts = application:get_all_env(raterl),
    Queues = proplists:get_value(queues, Opts, []),
    lists:foreach(fun({_QueueName, _QueueOpts} = Queue) ->
                    {ok, _} = raterl_queue:new(Queue)
                  end, Queues),
    {ok, #state{queues = Queues}}.

handle_call({reconfigure, Queues}, _From, State) ->
    CurrentQueues = State#state.queues,
    ToRemove = CurrentQueues -- Queues,
    ToAdd = Queues -- CurrentQueues,
    lists:foreach(
      fun ({QueueName, _QueueOpts}) ->
              ok = raterl_queue:stop(QueueName)
      end,
      ToRemove),
    lists:foreach(
      fun ({_QueueName, _QueueOpts} = Queue) ->
              {ok, _} = raterl_queue:new(Queue)
      end,
      ToAdd),
    NewState = State#state{ queues = Queues },
    {reply, ok, NewState}.

handle_cast(_, State) ->
    {noreply, State}.

handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal functions
%%====================================================================

