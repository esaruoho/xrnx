--[[============================================================================
Renoise Socket API Reference
============================================================================]]--

--[[

This reference describes the built-in socket support for Lua scripts in Renoise.
Sockets can be used to send/receive data over process boundaries or exchange
data across computers in a network (Internet). The socket API in Renoise has
server support (which can respond to multiple connected clients) and client
support (send/receive data to/from a server).

Right now UDP and TCP protocols are supported. The class interfaces for UDP
and TCP sockets behave exactly the same, do not depend on the used protocol,
so both protocols are easily exchangeable when needed.

Please read the INTRODUCTION.txt first to get an overview about the complete
API, and scripting in Renoise in general...

Do not try to execute this file. It uses a .lua extension for markups only.


-------- Overview

The socket server interface in Renoise is asynchronous (callback based), which
means server calls never block or wait, but are served in the background.
As soon a connection is established or messages arrive, a set of specified
callbacks are invoked to respond to messages on the fly and only when needed.

Socket clients in Renoise do block with timeouts to receive messages and
assume that you only expect a response from a server after having sent
something to it (i.e.: GET HTTP). To constantly "poll" a connection to a server,
you can nevertheless do so in, for example, idle timers by specifying a timeout
of 0 when calling receive(message) to see if there's some message pending
from the server.


-------- Error handling

All socket functions which can fail, will return an error string as an optional
second return value. They do not call Luas error() handler, so you can decide on
your own how to deal with expected errors like connection timeouts, connection
failures and so on. This also means you don't have to "pcall" socket functions
to handle "expected" errors.
Logic errors (setting invalid addresses, using disconnected sockets, passing
invalid timeouts and so on) will, as usual, fire a Luas runtime error (abort
your scripts and spit out an error). If you get such an error, then this usually
means that you did something wrong, have fed or used the sockets in a way that
does not make sense. Never "pcall" such errors, but fix the problems instead.


-------- Examples

-- for some small examples on how to use sockets in this API, have a look at the
"CodeSnippets.txt" file please. There are two simple client/server examples...

]]


--==============================================================================
-- Socket
--==============================================================================

--------------------------------------------------------------------------------
-- renoise.Socket
--------------------------------------------------------------------------------

-------- consts (renoise.Socket)

renoise.Socket.PROTOCOL_TCP
renoise.Socket.PROTOCOL_UDP


-------- Creating Socket Servers

-- creates a connected UPD or TCP server object. Use "localhost" as address to
-- use your systems default network address. protocol can be
-- renoise.Socket.PROTOCOL_TCP or renoise.Socket.PROTOCOL_UDP (by default TCP)
-- when instantiation and connection succeeded, a valid server object is
-- returned, else socket_error is set and the server object is nil.
-- using the create function with no server_address, allows you to create a 
-- server which allows connections to any address (for example localhost 
-- and some IP)
renoise.Socket.create_server( [server_address, ] server_port [, protocol]) ->
  [server (SocketServer or nil), socket_error (string or nil)]


-- Creating Socket Clients

-- create a connected UPD or TCP client. protocol can be
-- renoise.Socket.PROTOCOL_TCP or renoise.Socket.PROTOCOL_UDP (by default TCP)
-- timeout is the time we wait until the connection was established (1000 ms
-- by default). when instantiation and connection succeeded, a valid client
-- object is returned, else socket_error is set and the client object is nil
renoise.Socket.create_client(server_address, server_port [, protocol] [, timeout]) ->
  [client (SocketClient or nil), socket_error (string or nil)]


--------------------------------------------------------------------------------
-- renoise.Socket.SocketBase
--------------------------------------------------------------------------------

-- SocketBase is the base class for socket clients and servers. All
-- SocketBase properties and functions are available for servers and clients.

-------- properties

-- returns true while the socket object is valid and connected. Sockets can be 
-- manually closed (see socket:close()). client sockets can also get actively 
-- closed/refused by its server. In this case the client:receive() calls will 
-- fail and return an error
socket.is_open -> [boolean]

-- the sockets resolved local address (for example "127.0.0.1"
-- when a socket was bound to "localhost")
socket.local_address -> [string]

-- the sockets local port number, as specified while instantiated
socket.local_port -> [number]

-------- functions

-- closes the socket connection and releases all its resources. this will make
-- the socket useless, so any properties, calls to the socket will result in
-- errors. Can be useful to explicitly release a connection without waiting for
-- the dead object to be garbage collected of if you want to actively refuse a 
-- connection.
socket:close()


--------------------------------------------------------------------------------
-- renoise.Socket.SocketClient (inherits from SocketBase)
--------------------------------------------------------------------------------

-- a SocketClient can connect to other socket servers and send and
-- receive data from them on request. Connections to a server can not
-- change, they are specified when constructing a client. You can not reconnect
-- a client; ceate a new client instance instead.


-------- properties

-- address of the sockets peer, the socket address this client is connected to
socket_client.peer_address -> [string]

-- port of the sockets peer, the socket this client is connected to
socket_client.peer_port -> [number]


-------- functions

-- send a message string to the connected server. when sending failed, success
-- will be false and error_message is set
socket_client:send(message) ->
  [success (boolean), error_message (string or nil)]

-- receive a message string from the the connected server with the given 
-- timeout in milliseconds. mode can be one of "*line", "*all" or a number > 0, 
-- like Luas io.read's. \param timeout can be 0, which is useful for 
-- receive("*all"). this will only check and read pending data from the 
-- sockets queue.
--
-- mode "*line": will receive new data from the server or flush pending data 
--   that makes up a "line": a string that ends with a newline. remaining data
--   is kept buffered for upcoming receive calls and any kind of newlines 
--   are supported. the returned line will not contain the newline characters.
--
-- mode "*all": reads all pending data from the peer socket and also flushes 
--   internal buffers from previous receive line/byte calls (when present).
--   This will NOT read the entire requested content, but only the current 
--   buffer that is queued for the local socket from the peer. To read an 
--   entire HTTP page or file you may have to call receive("*all") multiple 
--   times until you got all you expect to get. 
--
-- mode "number > 0": tryies reading \param NumberOfBytes od data from the 
--   peer. Note that the timeout may be applied more than once, if more than 
--   one socket read is needed to receive the requested block.
-- 
-- when receiving failed or timed-out, the returned message will be nil and 
-- the returned error_message is set. The error message is "timeout" on timeouts, 
-- "disconnected" when the server actively refused/disconnected your client. 
-- any other errors are system dependent, and should only be used for display 
-- purposes.
-- once you got an error from receive, and this error is not a "timeout", the 
-- socket will already be closed and thus must be recreted in order to retry the 
-- communication with the server. any attempts to use a closed socket will fire
-- a runtime error.
socket_client:receive(mode, timeout_ms) ->
  [message (string or nil), error_message (string or nil)]


--------------------------------------------------------------------------------
-- renoise.Socket.SocketServer (inherits from SocketBase)
--------------------------------------------------------------------------------

-- a SocketServer handles one or more clients in the background, interacts
-- only with callbacks with connected clients.
-- this background polling can be started and stopped on request


-------- properties

-- returns true while the server is running (the server is up and running)
server_socket.is_running -> [boolean]


-------- functions

-- start running the server by specifying a class or table which defines the
-- callback functions for the server (see "callbacks" below for more info)
server_socket:run(notifier_table_or_call)

-- stop a running server
server_socket:stop()

-- suspends the calling thread by the given timeout, and calls the servers
-- callback methods as soon as something has happened in the server while waiting.
-- should be avoided when you can deal with messages asynchronously only.
server_socket:wait(timeout_ms)


-------- callbacks

-- all callback properties are optional. when not specified, no error is fired.
-- So you can for example skip specifying "socket_accepted" if you have no use
-- for this...

-- notifier table example:

notifier_table = {
  socket_error = function(error_message)
    -- an error happened in the servers background thread
  end,

  socket_accepted = function(socket)
    -- FOR TCP CONNECTIONS ONLY: called as soon as a new client
    -- connected to your server. the passed socket is
    -- a ready to use connection to the socket that has sent the message
  end,

  socket_message = function(socket, message)
    -- a message was received from a client. the passed socket is a ready
    -- to use connection to the socket that has sent the message for TCP 
    -- connections. for UDP, a "dummy" socket is passed, which can only be 
    -- use to query the peer address and port the message was sent from
  end
}

-- notifier class example:
-- Note: You must pass an instance of a class, like server_socket:run(MyNotifier())

class "MyNotifier"
  MyNotifier::__init()
    -- could pass a server ref or something else here, or simply do nothing
  end

  function MyNotifier:socket_error(error_message)
    -- an error happened in the servers background thread
  end

  function MyNotifier:socket_accepted(socket)
    -- FOR TCP CONNECTIONS ONLY! called as soon as a client
    -- connected itself to your server. the passed socket is
    -- a ready to use connection to the socket that has sent the message
  end

  function MyNotifier:socket_message(socket, message)
    -- an message from a client was received. the passed socket is a ready
    -- to use connection to the socket that has sent the message for TCP 
    -- connections. for UDP, a "dummy" socket is passed, which can only be 
    -- use to query the peer address and port the message was sent from.
  end
