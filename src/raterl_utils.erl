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
%% @doc raterl utils.
%% @end
%%%-------------------------------------------------------------------

-module(raterl_utils).

%% API
-export([table_name/1,
         queue_name/1,
         maps_take/2]).

%%====================================================================
%% API functions
%%====================================================================

table_name(Name) ->
    list_to_atom("$$raterl_" ++ atom_to_list(Name)).

queue_name(Name) ->
    list_to_atom("raterl_" ++
                 atom_to_list(Name)).

-ifdef(NO_MAPS_TAKE).
maps_take(Key, Map) ->
    try maps:get(Key, Map) of
        Value ->
            UpdatedMap = maps:remove(Key, Map),
            {Value, UpdatedMap}
    catch
        error:{badkey, _} ->
            error
    end.
-else.
maps_take(Key, Map) ->
    maps:take(Key, Map).
-endif.

%%====================================================================
%% Internal functions
%%====================================================================

