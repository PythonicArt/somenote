A distributed Erlang system consists of a number of Erlang runtime systems communicating with each other. Each such runtime system is called a node. Message passing between processes at different nodes, as well as links and monitors, are transparent when pids are used. Registered names, however, are local to each node. This means that the node must be specified as well when sending messages, and so on, using registered names.

The distribution mechanism is implemented using TCP/IP sockets.


## Nodes
A node is an executing Erlang runtime system that has been given a name, using the command-line flag -name (long names) or -sname (short names).

The format of the node name is an atom name@host. name is the name given by the user. host is the full host name if long names are used, or the first part of the host name if short names are used. node() returns the name of the node.


## Node Connections

The nodes in a distributed Erlang system are loosely connected. The first time the name of another node is used, for example, if spawn(Node,M,F,A) or net_adm:ping(Node) is called, a connection attempt to that node is made.

Connections are by default transitive. If a node A connects to node B, and node B has a connection to node C, then node A also tries to connect to node C. This feature can be turned off by using the command-line flag -connect_all false, see the erl(1) manual page in ERTS.

If a node goes down, all connections to that node are removed. Calling erlang:disconnect_node(Node) forces disconnection of a node.

The list of (visible) nodes currently connected to is returned by nodes().

## Security

Authentication determines which nodes are allowed to communicate with each other. In a network of different Erlang nodes, it is built into the system at the lowest possible level. Each node has its own magic cookie, which is an Erlang atom.

**When a node tries to connect to another node, the magic cookies are compared. If they do not match, the connected node rejects the connection.**

**the process of creating a cookie**
At start-up, a node has a random atom assigned as its magic cookie and the cookie of other nodes is assumed to be nocookie. The first action of the Erlang network authentication server (auth) is then to read a file named $HOME/.erlang.cookie. If the file does not exist, it is created. The UNIX permissions mode of the file is set to octal 400 (read-only by user) and its contents are a random string. An atom Cookie is created from the contents of the file and the cookie of the local node is set to this using erlang:set_cookie(node(), Cookie). This also makes the local node assume that all other nodes have the same cookie Cookie.

Thus, groups of users with identical cookie files get Erlang nodes that can communicate freely and without interference from the magic cookie system. Users who want to run nodes on separate file systems must make certain that their cookie files are identical on the different file systems.

**connection between nodes with different cookie**
For a node Node1 with magic cookie Cookie to be able to connect to, or accept a connection from, another node Node2 with a different cookie DiffCookie, the function erlang:set_cookie(Node2, DiffCookie) must first be called at Node1. Distributed systems with multiple user IDs can be handled in this way.

The default when a connection is established between two nodes, is to immediately connect all other visible nodes as well. This way, there is always a fully connected network. If there are nodes with different cookies, this method can be inappropriate and the command-line flag -connect_all false must be set, see the erl(1) manual page in ERTS.

The magic cookie of the local node is retrieved by calling erlang:get_cookie().
