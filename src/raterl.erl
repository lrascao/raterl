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
%% @doc raterl.
%% @end
%%%-------------------------------------------------------------------

-module(raterl).

%% API
-export([run/2, run/3,
         info/1,
         modify_regulator/3,
         reconfigure_queues/1,
         query_regulator/3]).

%%====================================================================
%% API functions
%%====================================================================

run(Name, Fun) ->
    %% obtain the queue configuration from ets
    [{Name, Type, RegulatorName}] = ets:lookup(raterl, Name),
    run(Name, {Type, RegulatorName}, Fun).

run(Name, {Type, RegulatorName}, Fun) ->
    case ask(Name, Type, RegulatorName) of
        limit_reached ->
            limit_reached;
        {SlotSource, Slot} ->
            try
                Fun()
            after
                done(SlotSource, Slot)
            end
    end.

info(Name) ->
    raterl_queue:info(Name).

modify_regulator(Name, RegName, Limit) ->
    raterl_queue:modify_regulator(Name, RegName, Limit).

reconfigure_queues(Queues) ->
    raterl_server:reconfigure(Queues).

query_regulator(Name, rate, RegulatorName) ->
    Table = raterl_utils:table_name(Name),
    [{RegulatorName, Value}] = ets:lookup(Table, RegulatorName),
    Value.

%%====================================================================
%% Internal functions
%%====================================================================

ask(Name, rate, RegulatorName) ->
    Table = raterl_utils:table_name(Name),
    case ets:update_counter(Table, RegulatorName, [{2, -1, 0, 0}]) of
        [0] -> limit_reached;
        [_N] -> {rate, slot}
    end;
ask(Name, counter, _RegulatorName) ->
    raterl_queue:ask_for_counter_slot(Name).

done(rate, _) -> ok;
done(CounterPid, SlotRef) ->
    %% return one resource back to the pool
    raterl_queue:give_counter_slot_back(CounterPid, SlotRef).
