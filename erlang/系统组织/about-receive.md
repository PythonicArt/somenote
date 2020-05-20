
receive 操作
    从进程的邮箱中获取一条消息进行匹配,
        如果匹配成功
            有定时器的话, 清除定时器
            从邮箱中删除该消息
            执行该消息下的语句
            将缓存队列的消息按入队顺序再次进入进程邮箱, 清空缓存队列
        如果匹配不成功
            还有其他消息
                选取下一条消息匹配，从头开始执行
            没有其他消息
                此时邮箱中没有任何消息匹配

        对于没有可匹配消息处理的进程
            有超时计时器
                未到时
                    挂起等待
                到时
                    执行超时下的语句
                    将缓存队列的消息按入队顺序再次进入进程邮箱, 清空缓存队列
            没有计时器
                将邮箱中的所有消息按顺序进入缓存队列, 清空邮箱
                挂起进程, 直到新的消息来临

```cpp
for each msg in mailBox:
    if msg matched:
        有定时器的话, 清除定时器
        从邮箱中删除该消息
        执行该消息下的语句
        将缓存队列的消息按入队顺序再次进入进程邮箱, 清空缓存队列
    else:
        continue

if have timer:
    未到时
        原邮箱不变,
        挂起等待
    到时
        执行超时下的语句
        将缓存队列的消息按入队顺序再次进入进程邮箱, 清空缓存队列
else:
    将邮箱中的所有消息按顺序进入缓存队列, 清空邮箱
    挂起进程, 直到新的消息来临
```


以上的过程描述可以看出， 邮箱和缓存队列是两个消息队列

进程被唤醒的机制
    1. 新的消息到来
    2. 计时器时间到来(超时消息到来)

关于超时时间为0
    进程被唤醒 执行receive, 根据receive的操作流程, 会优先操作邮箱里的消息, 再考虑超时的消息.

注意对无法匹配的消息的处理，
    思想方法是当次的不能处理的消息缓存下来， 当新消息得到匹配的时候， 重新进入邮箱，
    或许此时代码已经得到升级， 能够被处理到。
    如果出现越来越多无法处理的消息， 进程的内存空间就会堆积， 增加每次地进队出队和重复遍历的时间
    影响效率. 需要保证所有消息都能得到处理

服务器类进程负责不断地处理消息，
    一个receive结束之后就是马上下一个receive, 直到邮箱为空挂起或超时的到来

使用receive实现下述操作
1. 定时器
```erlang
timer(Time, Func)->
    receive
    after Time ->
        Func()
    end.
```

2. 选择性接受
```erlang

```

3. 邮箱操作
    清除邮箱最开始的消息
        用两个receive, 第一个匹配调用消息， 第二个匹配任何消息即可
    清除邮箱一个指定消息
        用两个receive, 第一个匹配调用消息， 第二个匹配指定的消息
    清除邮箱所有消息
        重复执行receive, 直到邮箱空

```erlang
loop() -> %%主循环
    io:format("loop in"),
    receive
        ok ->
            io:format("receive ok,begin process"),
            io:format("receive ok,begin end"),
            loop();
        'flush' ->
            flush(),
            loop();
        {'flush', Msg} ->
            flush(Msg),
            loop();
        'flush_all' ->
            flush_all()
            loop()
    end.
flush() ->  %%清除一个消息
  receive
    Msg ->
      io:format("flush:~p", [Msg])
  after 0 ->
    ok
  end.
flush(Msg) ->  %%清除一个指定消息
  receive
    indicated ->
      io:format("flush:~p", [Msg])
  after 0 ->
    ok
  end.
flush_all() ->    %%清除所有的消息
  receive
    Msg ->
      io:format("flush:~p", [Msg]),
      flush_all()
  after 0 ->
    ok
  end.
```

4. 指定消息的处理顺序， 比如
先处理a 再处理b。
    用两个receive, 第一个只匹配a， 没有其他分句， 在匹配a后执行的语句， 进行receive b， 并且只匹配b

根据消息的优先级处理
    每次对邮箱进行排序

```erlang
fun()->
    receive
      'a' ->
        io:format("receive and process msg:~p", []),
        receive
           'b' ->
              io:format("receive and process msg:~p", [])
        end
    end.
```
