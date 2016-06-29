%% -------------------------------------------------------------------
%%
%% Copyright (c) 2015 Christopher Meiklejohn.  All Rights Reserved.
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

-module(lasp_type).
-author("Christopher Meiklejohn <christopher.meiklejohn@gmail.com>").

-include("lasp.hrl").

-export([new/1,
         update/4,
         merge/3,
         threshold_met/3,
         is_delta/1,
         is_inflation/3,
         is_strict_inflation/3,
         query/2]).

types() ->
    [
        {gcounter, {state_gcounter, undefined}},
        {gset, {state_gset, undefined}},
        {ivar, {state_ivar, undefined}},
        {orset, {state_oorset_ps, undefined}},
        {pair, {state_pair, undefined}},
        {pncounter, {state_pncounter, undefined}}
    ].

get_mode() ->
    lasp_config:get(mode, state_based).

get_type(T) ->
    get_type(T, get_mode()).

get_type(T, Mode) ->
    {ok, {StateType, PureOpType}} = orddict:find(T, types()),
    case Mode of
        delta_based ->
            StateType;
        state_based ->
            StateType;
        pure_op_based ->
            PureOpType
    end.

remove_args({T, _Args}) ->
    T;
remove_args(T) ->
    T.

is_delta({_Type, {delta, _CRDT}}) ->
    true;
is_delta(_) ->
    false.

%% @doc Is strict inflation?
is_strict_inflation(Type, Previous, Current) ->
    T = get_type(remove_args(Type)),
    T:is_strict_inflation(Previous, Current).

%% @doc Is inflation?
is_inflation(Type, Previous, Current) ->
    T = get_type(remove_args(Type)),
    T:is_inflation(Previous, Current).

%% @doc Determine if a threshold is met.
threshold_met(Type, Value, {strict, Threshold}) ->
    T = get_type(remove_args(Type)),
    T:is_strict_inflation(Threshold, Value);
threshold_met(Type, Value, Threshold) ->
    T = get_type(remove_args(Type)),
    T:is_inflation(Threshold, Value).

%% @doc Initialize a new variable for a given type.
new(Type) ->
    T = get_type(remove_args(Type)),
    case Type of
        {_T0, Args} ->
            T:new(Args);
        _T0 ->
            T:new()
    end.

%% @doc Use the proper type for performing an update.
update(Type, Operation, Actor, Value) ->
    Mode = get_mode(),
    T = get_type(remove_args(Type), Mode),
    RealActor = get_actor(T, Actor),
    case Mode of
        delta_based ->
            T:delta_mutate(Operation, RealActor, Value);
        state_based ->
            T:mutate(Operation, RealActor, Value);
        pure_op_based ->
            ok %% @todo
    end.

%%private
get_actor(state_oorset_ps, {{StorageId, _TypeId}, Actor}) ->
    {StorageId, Actor};
get_actor(_Type, {_Id, Actor}) ->
    Actor;
get_actor(_Type, Actor) ->
    Actor.

%% @doc Call the correct merge function for a given type.
merge(Type, Value0, Value) ->
    T = get_type(remove_args(Type)),
    T:merge(Value0, Value).

%% @doc Return the value of a CRDT.
query(Type, Value) ->
    T = get_type(remove_args(Type)),
    T:query(Value).
