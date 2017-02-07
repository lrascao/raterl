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
%% @doc raterl top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(raterl_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    QueueSupervisorSpec = child_spec(supervisor, raterl_queue_sup),
    ServerSpec = child_spec(worker, raterl_server),
    RestartStrategy = {one_for_one, 5, 10},
    Children = [QueueSupervisorSpec, ServerSpec],
    {ok, {RestartStrategy, Children}}.

%%====================================================================
%% Internal functions
%%====================================================================

child_spec(Type, Module) ->
    {Module, {Module, start_link, []},
          transient, 5000, Type, [Module]}.

