# a simple tcp server

```erlang
server() ->
    {ok, LSock} = gen_tcp:listen(5678, [binary, {packet, 0},
                                        {active, false}]),
    {ok, Sock} = gen_tcp:accept(LSock),
    {ok, Bin} = do_recv(Sock, []),
    ok = gen_tcp:close(Sock),
    ok = gen_tcp:close(LSock),
    Bin.

do_recv(Sock, Bs) ->
    case gen_tcp:recv(Sock, 0) of
        {ok, B} ->
            do_recv(Sock, [Bs, B]);
        {error, closed} ->
            {ok, list_to_binary(Bs)}
    end.

client() ->
    SomeHostInNet = "localhost", % to make it runnable on one machine
    {ok, Sock} = gen_tcp:connect(SomeHostInNet, 5678,
                                 [binary, {packet, 0}]),
    ok = gen_tcp:send(Sock, "Some Data"),
    ok = gen_tcp:close(Sock).

```

# tcp 基本原理
tcp的基本原理是创建连接， 通信的双方通过这个连接不断地传输信息， 当连接关闭， 两方完成一次通信
计算机划分多个端口用于传输信息，

一方 侦听一个端口， 识别连接; 另一方知道对方的端口后发起连接， 建立连接的过程是 三次握手
接收方的一个端口可以建立多个连接, 也就是可以同时和很多个发起连接者进行通信. 如何区分同一端口的不同链接？
可以限制端口的连接数量来限制吞吐量， 避免接收方过于忙碌， 响应慢

当一个连接建立之后， 就是不断地进行数据通信， 不断地发送和接收消息
当连接方不需要再通信， 主动发起断开， 这个过程是 四次挥手. 必须是发送方发起断开吗？ 接收方断开， 流程是怎样的？


回到上面的例子,  server使用 listen 对服务器上一个端口侦听 得到一个侦听socket LSocket， 使用 accept 等待连接的到来
client 通过约定的端口， 使用connect 发起连接，

当建立连接之后, 双方就都得到一个连接socket Socket, 即 connect 和 accept的返回

双方通过 send 和 recv 不断的发送和接收消息

关于owner
建立或响应连接的那个进程, 即调用connect/accept的进程, 是此次连接的owner,  
只有owner才能通过send/recv 获得消息, 应该底层有一个注册表， 有连接和进程的映射

使用 controlling_process 可以进行owner的切换
```js
    controlling_process(Socket, Pid) -> ok | {error, Reason}
```


值得注意的地方
1. 连接建立的过程中  connect 和 accept都会被挂起, 而不是马上返回。这个机制的实现耐人寻味
2. 以上是一个非常朴素的版本， 为了实现高效， 安全， 稳定的服务器， 需要增加更多的配置， 通过侦听端口和建立连接时指定不同的参数来实现
数据时如何到达的, 实现方式？
如何保证数据准确地到达?
如何保证网络的通畅？
如何处理超时但是不会断开的连接？


另一个例子, 使用多个进程来同时处理通信， 每一个进程响应一个连接
```erlang
start(Num,LPort) ->
    case gen_tcp:listen(LPort,[{active, false},{packet,2}]) of
        {ok, ListenSock} ->
            start_servers(Num,ListenSock),
            {ok, Port} = inet:port(ListenSock),
            Port;
        {error,Reason} ->
            {error,Reason}
    end.

start_servers(0,_) ->
    ok;
start_servers(Num,LS) ->
    spawn(?MODULE,server,[LS]),
    start_servers(Num-1,LS).

server(LS) ->
    case gen_tcp:accept(LS) of
        {ok,S} ->
            loop(S),
            server(LS);
        Other ->
            io:format("accept returned ~w - goodbye!~n",[Other]),
            ok
    end.

loop(S) ->
    inet:setopts(S,[{active,once}]),
    receive
        {tcp,S,Data} ->
            Answer = process(Data), % Not implemented in this example
            gen_tcp:send(S,Answer),
            loop(S);
        {tcp_closed,S} ->
            io:format("Socket ~w closed [~w]~n",[S,self()]),
            ok
    end.
```
