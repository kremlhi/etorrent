%% Minimal HTTP BitTorrent tracker for Common Test suites.
%%
%% Uses gen_tcp directly so it can start before the cowboy application
%% is brought up by start_app/2 in the test suite.
-module(etorrent_test_tracker).
-behaviour(gen_server).

-export([start/1, stop/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {lsock, peers}).

start(Port) ->
    gen_server:start({local, ?MODULE}, ?MODULE, Port, []).

stop(Pid) ->
    gen_server:stop(Pid).

init(Port) ->
    {ok, LSock} = gen_tcp:listen(Port, [binary, {reuseaddr, true}, {active, false}]),
    Peers = ets:new(tracker_peers, [bag, public]),
    self() ! accept,
    {ok, #state{lsock = LSock, peers = Peers}}.

handle_info(accept, #state{lsock = LSock, peers = Peers} = State) ->
    case gen_tcp:accept(LSock, 50) of
        {ok, Sock} ->
            {ok, {RemoteIP, RemotePort}} = inet:peername(Sock),
            ct:pal("tracker: accepted connection from ~p:~p", [RemoteIP, RemotePort]),
            spawn(fun() -> handle_request(Sock, Peers) end),
            self() ! accept;
        {error, timeout} ->
            self() ! accept;
        {error, _} ->
            ok
    end,
    {noreply, State};
handle_info(_, State) ->
    {noreply, State}.

handle_call(_, _, State) -> {reply, ok, State}.
handle_cast(_, State)    -> {noreply, State}.

terminate(_, #state{lsock = LSock, peers = Peers}) ->
    ets:delete(Peers),
    gen_tcp:close(LSock),
    ok.

code_change(_, State, _) -> {ok, State}.

handle_request(Sock, Peers) ->
    case gen_tcp:recv(Sock, 0, 5000) of
        {ok, Data} -> handle_http(Sock, Data, Peers);
        _          -> gen_tcp:close(Sock)
    end.

handle_http(Sock, Data, Peers) ->
    [RequestLine | _] = binary:split(Data, <<"\r\n">>),
    case binary:split(RequestLine, <<" ">>, [global]) of
        [<<"GET">>, Path, _] -> handle_announce(Sock, Path, Peers);
        _                    -> respond(Sock, 400, <<"Bad Request">>)
    end.

handle_announce(Sock, Path, Peers) ->
    case binary:split(Path, <<"?">>) of
        [_, QS] ->
            Params    = parse_qs(QS),
            InfoHash  = proplists:get_value(<<"info_hash">>, Params, <<>>),
            AnnPort   = binary_to_integer(
                          proplists:get_value(<<"port">>, Params, <<"0">>)),
            {ok, {PeerIP, _}} = inet:peername(Sock),
            IpBin = list_to_binary(inet:ntoa(PeerIP)),
            ets:insert(Peers, {InfoHash, IpBin, AnnPort}),
            AllPeers = ets:lookup(Peers, InfoHash),
            ct:pal("tracker: announce from ~s:~p ih=~p, all_peers=~p",
                   [IpBin, AnnPort, binary:part(InfoHash, 0, min(4, byte_size(InfoHash))), AllPeers]),
            PeerList  = [[{<<"ip">>, Ip}, {<<"port">>, P}]
                         || {_, Ip, P} <- AllPeers],
            Body      = iolist_to_binary(etorrent_bcoding:encode(
                            [{<<"interval">>, 30}, {<<"peers">>, PeerList}])),
            respond(Sock, 200, Body);
        _ ->
            respond(Sock, 400, <<"Bad Request">>)
    end.

respond(Sock, Code, Body) ->
    StatusText = case Code of 200 -> <<"OK">>; _ -> <<"Error">> end,
    Len = integer_to_binary(byte_size(Body)),
    Response = <<"HTTP/1.0 ", (integer_to_binary(Code))/binary, " ",
                 StatusText/binary, "\r\nContent-Length: ", Len/binary,
                 "\r\n\r\n", Body/binary>>,
    gen_tcp:send(Sock, Response),
    gen_tcp:close(Sock).

parse_qs(QS) ->
    [parse_param(P) || P <- binary:split(QS, <<"&">>, [global])].

parse_param(P) ->
    case binary:split(P, <<"=">>) of
        [K, V] -> {percent_decode(K), percent_decode(V)};
        [K]    -> {percent_decode(K), <<>>}
    end.

percent_decode(<<$%, H, L, Rest/binary>>) ->
    Byte = list_to_integer([H, L], 16),
    <<Byte, (percent_decode(Rest))/binary>>;
percent_decode(<<$+, Rest/binary>>) ->
    <<$\s, (percent_decode(Rest))/binary>>;
percent_decode(<<C, Rest/binary>>) ->
    <<C, (percent_decode(Rest))/binary>>;
percent_decode(<<>>) ->
    <<>>.
