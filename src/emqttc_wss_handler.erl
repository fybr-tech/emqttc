-module(emqttc_wss_handler).

-behaviour(websocket_client_handler).

-record(wss_comm_handler, {tx_pid, rx_pid}).

-export([
         start_link/2,
         init/2,
         websocket_send/2,
         websocket_handle/3,
         websocket_info/3,
         websocket_terminate/3
        ]).

start_link(Endpoint, Name) ->
    process_flag(trap_exit, true),
    crypto:start(),
    ssl:start(),
    websocket_client:start_link(Endpoint, ?MODULE, [Name]).

init([], _ConnState) ->
    {ok, undefined};

init(Args, _ConnState) ->
    NameArg = hd(Args),
    Name = proplists:get_value(name, NameArg),
    {ok, Name}.

websocket_send(Name, Data) ->
    case ets:lookup(websocket_map, Name) of
        [{Name, CommHandler}] ->
            Pid = CommHandler#wss_comm_handler.tx_pid,
            websocket_client:cast(Pid, {binary, Data});
        [] -> io:format("Cannot send to ~p~n", [Name]),
            ok
    end.

websocket_handle({pong, _}, _ConnState, State) ->
    {ok, State};
websocket_handle({binary, Msg}, _ConnState, State) ->
    case ets:lookup(websocket_map, State) of
        [{State, CommHandler}] ->
            CommHandler#wss_comm_handler.rx_pid ! {wss, Msg};
        [] -> io:format("No websocket connection found for ~p~n", [State]),
            ok
    end,
    {ok, State};
websocket_handle({text, _Msg}, _ConnState, 5) ->
    {close, <<>>, "done"};
websocket_handle({text, _Msg}, _ConnState, State) ->
    BinInt = list_to_binary(integer_to_list(State)),
    {reply, {text, <<"hello, this is message #", BinInt/binary >>}, State + 1}.

websocket_info(start, _ConnState, State) ->
    {reply, {text, <<"erlang message received">>}, State}.

websocket_terminate(Reason, _ConnState, State) ->
    io:format("Websocket closed in state ~p wih reason ~p~n",
              [State, Reason]),
    ok.

