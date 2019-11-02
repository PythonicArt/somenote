# Erlang networking kernel.

The net kernel is a system process, registered as net_kernel, which must be operational for distributed Erlang to work. The purpose of this process is to implement parts of the BIFs spawn/4 and spawn_link/4, and to provide monitoring of the network.

An Erlang node is started using command-line flag -name or -sname:

```erlang
    $ erl -sname foobar
```

It is also possible to call net_kernel:start([foobar]) directly from the normal Erlang shell prompt:
```erlang
1> net_kernel:start([foobar, shortnames]).
{ok,<0.64.0>}
(foobar@gringotts)2>
```

Normally, connections are established automatically when another node is referenced. This functionality can be disabled by setting Kernel configuration parameter dist_auto_connect to never, see kernel(6). In this case, connections must be established explicitly by calling connect_node/1.

Which nodes that are allowed to communicate with each other is handled by the magic cookie system, see section Distributed Erlang in the Erlang Reference Manual.
