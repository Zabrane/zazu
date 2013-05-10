-module(zazu).
-export([start/3, do/2, kill/1]).
-export([start/0]).

% --------- API ----------
start(Host, Port, Nick) ->
  spawn(fun() -> connect(Host, Port, Nick) end).

% for development only
start() ->
  spawn(fun() -> connect("127.0.0.1", 6667, "rze") end).

do(Pid, Cmd) ->
  Pid ! Cmd.

kill(Pid) ->
  Pid ! quit.
% --------- API ------------

connect(Host, Port, Nick) ->
  {ok, Socket} = gen_tcp:connect(Host, Port, [{keepalive, true}]),
  cmd(Socket, string:join(["NICK", Nick], " ")),
  cmd(Socket, string:join(["USER", Nick, "0 * :zazu bot"], " ")),
  cmd(Socket, "join #hi"), % for development only
  loop(Socket).

loop(Socket) ->
  receive
    {tcp, _, Msg} ->
      io:format("~p~n", [Msg]),
      handle(Socket, Msg),
      loop(Socket);
    quit ->
      cmd(Socket, "QUIT :killed from my master"),
      gen_tcp:close(Socket);
    Command ->
      cmd(Socket, Command),
      loop(Socket)
  end.

% Handles incoming TCP messages   
handle(Socket, Msg) ->
  case string:tokens(Msg, " ") of
    ["PING"|_] ->
      cmd(Socket, re:replace(Msg, "PING", "PONG", [{return, list}]));
    [User, "PRIVMSG", Channel|[":zazu"|Message]] ->
      io:format("~p~n", [Message]),
      handle(Socket, User, Channel, strip_msg(Message));
    _ ->
      loop(Socket)
  end.

% Handles recognized incoming messages
handle(Socket, User, Channel, [H|_]) when H == "malaka" ->
  cmd(Socket, reply({targeted, Channel, fetch_nick(User), "gamiesai"}));
handle(Socket, User, Channel, [H|T]) when H == "announce" ->
  inets:start(),
  httpc:request(post, { "http://0.0.0.0:3030/widgets/welcome", [], "application/x-www-formurlencoded", "\{ \"auth_token\": \"YOUR_AUTH_TOKEN\", \"text\": \"" ++ construct_message(T) ++ "\" \}" }, [], []),
  cmd(Socket, reply({targeted, Channel, fetch_nick(User), "announced"}));
handle(Socket, _User, Channel, _Msg) ->
  cmd(Socket, reply({public, Channel, "unrecognized command"})).

% Constructs IRC PRIVMSG replies to send to the server
reply({targeted, Channel, Nick, Answer}) ->
  "PRIVMSG" ++ " " ++ Channel ++ " " ++ ":" ++ Nick ++ " " ++ Answer;
reply({public, Channel, Answer}) ->
  "PRIVMSG" ++ " " ++ Channel ++ " " ++ ":" ++ Answer.

% Normalizes and sends a TCP packet to the server
cmd(Socket, Command) ->
  case string:right(Command, 2) of
    "\r\n" -> gen_tcp:send(Socket, Command);
    _      -> gen_tcp:send(Socket, string:join([Command, "\r\n"], ""))
  end.

fetch_nick(User) ->
  string:sub_string(string:sub_word(User, 1, $!), 2).

% Accepts an incoming message as a list and strips trailing newlines
strip_msg(Message) ->
  Strip = fun(X) -> re:replace(X, "\r\n", "", [{return, list}]) end,
  lists:map(Strip, Message).

construct_message(L) ->
  string:join(L, " ").

% add documentation
% read msgs only from the self process?
% handle each msg to a separate proc?
