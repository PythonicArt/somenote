# erl <arguments>
Starts an Erlang runtime system.
The arguments can be divided into emulator flags, flags, and plain arguments:

## emulator flags
    Any argument starting with character + is interpreted as an emulator flag.
    As indicated by the name, emulator flags control the behavior of the emulator.

## flags
    Any argument starting with character - (hyphen) is interpreted as a flag, which is to be passed to the Erlang part of the runtime system, more specifically to the init system process, see init(3).

    The init process itself interprets some of these flags, the init flags. It also stores any remaining flags, the user flags. The latter can be retrieved by calling **init:get_argument/1**.

## plain arguments
    Plain arguments are not interpreted in any way. They are also stored by the init process and can be retrieved by calling **init:get_plain_arguments/0**.
    Plain arguments can occur before the first flag, or after a -- flag. Also, the -extra flag causes everything that follows to become plain arguments.

# 启动一个程序， 相关内容
## 1. 指定节点名称
    -name
        Makes the Erlang runtime system into a distributed node. This flag invokes all network servers necessary for a node to become distributed; see net_kernel(3). It is also ensured that epmd runs on the current host before Erlang is started; see epmd(1).and the -start_epmd option.
        The node name will be **Name@Host**, where Host is the fully qualified host name of the current host. For short names, use flag -sname instead.

    -sname
        Makes the Erlang runtime system into a distributed node, similar to -name, but the host name portion of the node name Name@Host will be the short name, not fully qualified.

        If the node is started with command-line flag -sname, the node name is foobar@Host, where Host is the short name of the host (not the fully qualified domain name). If started with flag -name, the node name is foobar@Host, where Host is the fully qualified domain name.

        **This is sometimes the only way to run distributed Erlang if the Domain Name System (DNS) is not running.** No communication can exist between nodes running with flag -sname and those running with flag -name, as node names must be unique in distributed Erlang systems.

## 2. 指定cookie
    -setcookie

## 3. 指定可执行目录，beam目录
    -pa Dir1 Dir2 ...


## 4. 指定配置文件
    -config
        Specifies the name of a configuration file, Config.config, which is used to configure applications; see app(4) and application(3).

## 5. 指定启动时执行的操作
    -s Mod [Func [Arg1, Arg2, ...]] (init flag)
        Makes init call the specified function. **Func defaults to start**. If no arguments are provided, the function is assumed to be of arity 0. Otherwise it is assumed to be of arity 1, taking the list [Arg1,Arg2,...] as argument.

    程序启动时， 通过init模块接收和解析指定的标志和参数
    Example:
    ```erlang
        erl -s foo -s foo bar -s foo bar baz 1 2
        This starts the Erlang runtime system and evaluates the following functions:
        foo:start()
        foo:bar()
        foo:bar([baz, '1', '2']).
    ```
    The functions are executed sequentially in an initialization process, which then terminates normally and passes control to the user.
    **This means that a -s call that does not return blocks further processing**; to avoid this, use some variant of spawn in such cases.
    **All arguments are passed as atoms.** Because of the limited length of atoms, it is recommended to use -run instead.

    -run
        It is almost the same as -s, but all arguments are passed as strings.


## 6. 指定环境变量
    -env
        Sets the host OS environment variable Variable to the value Value for the Erlang runtime system.


## 7. 其他选项
    -connect_all false
        If this flag is present, global does not maintain a fully connected network of distributed Erlang nodes, and then global name registration cannot be used

        Connections are by default transitive. If a node A connects to node B, and node B has a connection to node C, then node A also tries to connect to node C. This feature can be turned off by using the command-line flag -connect_all false 

    -remsh Node
        Starts Erlang with a remote shell connected to Node. Requires either -name or -sname to be given. If Node does not contain a hostname, one is automatically taken from -name or -sname

    -eval Expr
        Scans, parses, and evaluates an arbitrary expression Expr during system initialization. If any of these steps fail (syntax error, parse error, or exception during evaluation), Erlang stops with an error message. In the following example Erlang is used as a hexadecimal calculator:

        ```erlang
            erl -noshell -eval 'R = 16#1F+16#A0, io:format("~.16B~n", [R])' -s erlang halt
            BF
        ```

    -noinput
        Ensures that the Erlang runtime system never tries to read any input.

    -noshell
        Starts an Erlang runtime system with no shell. This flag makes it possible to have the Erlang runtime system as a component in a series of Unix pipes.

    -detached
        Starts the Erlang runtime system detached from the system console. Useful for running daemons and backgrounds processes. Implies -noinput.

    -hidden
        Starts the Erlang runtime system as a hidden node, if it is run as a distributed node. Hidden nodes always establish hidden connections to all other nodes except for nodes in the same global group.
        适合remsh

## 8. emulator flag
    +K

    +P Number
        Sets the maximum number of **simultaneously existing processes** for this system if a Number is passed as value. Valid range for Number is [1024-134217727]

    +t size
        Sets the maximum **number of atoms** the virtual machine can handle. Defaults to 1,048,576.

    +fnu[{w|i|e}]
        The virtual machine works with filenames as if they are encoded using UTF-8 (or some other system-specific Unicode encoding). This is the default on operating systems that enforce Unicode encoding, that is, Windows and MacOS X.

        The +fnu switch can be followed by w(default), i, or e to control how wrongly encoded filenames are to be reported:

    +hmbs Size
        Sets the default binary virtual heap size of processes to the size Size.

    +zdbbl
        Sets the distribution buffer busy limit (dist_buf_busy_limit) in kilobytes. Valid range is 1-2097151. Defaults to 1024.

        A larger buffer limit allows processes to buffer more outgoing messages over the distribution. When the buffer limit has been reached, sending processes will be suspended until the buffer size has shrunk. The buffer limit is per distribution channel. A higher limit gives lower latency and higher throughput at the expense of higher memory use.
