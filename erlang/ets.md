
基本内容

1. ets 是一个键值对存储系统， 用于存储大量的数据
2. ets常驻内存， 由系统组件 ets模块进行数据管理
3. 当一个元组插入到ets表后， 这个数据从进程的栈复制到ets表里
4. 当要查询时， 找到的元组会从ets中复制到进程的栈上
5. ets没有持续化， dets有此功能
6. ets是一个独立的进程， ets表的数据保存在自己的进程里
7. Notice that there is no automatic garbage collection for tables. Even if there are no references to a table from any process, it is not automatically destroyed unless the owner process terminates.
8.have constant access time to the data. (In the case of ordered_set, access time is proportional to the logarithm of the number of stored objects)
9. 键值对， 任意的erlang数据类型都可以做key
10. 数据的分享，
权限
    private
    public

表的类型
1. set
2. ordered set
3. bag
4. duplicate bag

set bag 的区别
1. set不允许同键， 而bag可以。 即不同键时， 同一个key的数据只有一条
2. ordered set 即排过序的set
3. duplica bag 即 同一个元组可以多次出现

效率
内部实现是 散列表， 哈希的方式。
使用异键表会有空间开销（why）, 判断键是否存在?
有序异键会带来时间开销， 插入有序异键表的时间与条目数量的对数成比例
同键表比异键表效率更低， 每次插入需要比较与其他同键的元素是否相等(from erlang程序设计 第二版)

并发的保证
    This module provides some limited support for concurrent access. All updates to single objects are guaranteed to be both atomic and isolated.


操作方法
1. 创建
    new(Name, Options) -> tid() | atom()
    Options
    Option =
        Type | Access | named_table |
        {keypos, Pos} |
        {heir, Pid :: pid(), HeirData} |
        {heir, none} |
        Tweaks

    表的标识
        tid 是一个表的标记， The table identifier can be sent to other processes so that a table can be shared between different processes within a node.
        当指定 named_table选项时, 会返回指定的名字作为 identifier
        {keypos, Pos} 决定了哪个字段是key，不同表的类型根据这个位置做判断

    权限
        public
            Any process can read or write to the table.
        protected
            The owner process can read and write to the table.
            Other processes can only read the table.
            This is the default setting for the access rights.
        private
            Only the owner process can read or write to the table.

    指定继承
        Set a process as heir. The heir inherits the table if the owner terminates. Message {'ETS-TRANSFER',tid(),FromPid,HeirData} is sent to the heir when that occurs.        

    性能选项 Tweaks
        Tweaks =
            {write_concurrency, boolean()}
                false
                    任何写修改都是独立互斥的，并且在操作完成之前都会阻塞住其他操作的访问
                true
                    相反，可以并发修改
                    This is achieved to some degree at the expense of memory consumption and the performance of sequential access and concurrent reading.
                    这在某种程度上以牺牲内存消耗和顺序访问和并发读取的性能的方式而实现的

            {read_concurrency, boolean()}

            You typically want to enable this option when concurrent read operations are much more frequent than write operations, or when concurrent reads and writes comes in large read and write bursts (that is, many reads not interrupted by writes, and many writes not interrupted by reads).
            当并发读操作远比写操作更频繁， 或是当 并发读和写大量来临时（互不中断, 交叉）, 比如游戏中的market 商品订单

            You typically do not want to enable this option when the common access pattern is a few read operations interleaved with a few write operations repeatedly. In this case, you would get a performance degradation by enabling this option.            

            当读操作和写操作重复地交叉时， 不要使用

            compressed
                压缩存储， 更节省空间


2. 插入
    insert(Tab, ObjectOrObjects) -> true
        ObjectOrObjects = tuple() | [tuple()]
        必须是tuple, 单个值没有意义

    insert_new(Tab, ObjectOrObjects) -> boolean()
        当key不存在时才insert， 否则放弃

3. 删除
    整张表
        delete(Tab) -> true
    清空
        delete_all_objects(Tab) -> true
    按key删除
        delete(Tab, Key) -> true

3. 查询
    lookup(Tab, Key) -> [Object]
        对于set, Key需要全匹配, 虽然只有一个元素， 但是仍然返回一个列表
        对于ordered_set, Key只需要compares equal, 1.0 和 1 查询的结果是相同的
        查不到时 返回 []

    lookup_element(Tab, Key, Pos) -> Elem
        指定key的元素的Pos位置下的值
        先根据lookup找到结果， 再根据Pos选出所有元素中该位置的值
        If no object with key Key exists, the function exits with reason badarg.

3. 匹配

1 返回指定的结果
match(Tab, Pattern) -> [Match]
Matches the objects in table Tab against pattern Pattern.
```erlang
    A pattern is a term that can contain:
    * Bound parts (Erlang terms)
    * '_' that matches any Erlang term
    * Pattern variables '$N', where N=0,1,...
    Match的结果是一个列表，
        元素为每一个满足匹配的record的列表, 由匹配模式中指定的变量按顺序组成

    The function returns a list with one element for each matching object, where each element is an ordered list of pattern variable bindings,
    6> ets:match(T, '$1'). % Matches every object in table
        [[{rufsen,dog,7}],[{brunte,horse,5}],[{ludde,dog,5}]]
    7> ets:match(T, {'_',dog,'$1'}).
        [[7],[5]]
    8> ets:match(T, {'_',cow,'$1'}).
        []
```
2 返回匹配到的元组
match_object(Tab, Pattern) -> [Object]

meridiem 

5. 搜索
    select(Tab, MatchExpression) -> [Match]

    提供 查询条件进行匹配
    ```erlang
    MatchExpression ::= [ MatchFunction, ... ]
    MatchFunction ::= { MatchHead, MatchConditions, MatchBody }
    MatchHead ::= MatchVariable | '_' | { MatchHeadPart, ... }
    MatchHeadPart ::= term() | MatchVariable | '_'
    MatchVariable ::= '$<number>'

    1. {匹配头， 匹配条件， 匹配结果构造}
    匹配头 给出 匹配模式， 需要满足的格式
    对于 {a, b, c} 组成的ets
    '_' 可以匹配任意类型的数据
    term() 匹配一个erlang 类型 如 {a, '_', '_'}, 匹配以a开头的结构
    MatchVariable 对字段进行编号， 在之后的条件判断和结果筛选中用到
        如 '$1', 匹配每一个record, 并把record标记为 $1
        如 {a, '_', '_'}, 匹配以a开头的record
        如 {a, '$1', '$2'}, 匹配以a开头的record, 并对后两个字段分别标记为 $1,$2

    MatchConditions ::= [ MatchCondition, ...] | []
    MatchCondition ::= { GuardFunction } | { GuardFunction, ConditionExpression, ... }
    ConditionExpression ::= ExprMatchVariable | { GuardFunction } | { GuardFunction, ConditionExpression, ... } | TermConstruct
    TermConstruct = {{}} | {{ ConditionExpression, ... }} | [] | [ConditionExpression, ...] | #{} | #{term() => ConditionExpression, ...} | NonCompositeTerm | Constant

    2. 匹配条件, 根据第一步匹配得到的元组后再进行条件筛选

    The variable '$_' expands to the whole match target term, 整个匹配的record
    The variable '$$' expands to a list of the values of all bound variables in order (that is, ['$1','$2', ...]). 刚刚绑定的变量的列表

    MatchBody ::= [ ConditionExpression, ... ]

    3. 结果构造, 通过前两步得到满足条件的record, 再根据给定的形式， 得到最后的结果

    Constant ::= {const, term()}
    NonCompositeTerm ::= term() (not list or tuple or map)
    ExprMatchVariable ::= MatchVariable (bound in the MatchHead) | '$_' | '$$'
    GuardFunction ::= BoolFunction | abs | element | hd | length | map_get | map_size | node | round | size | bit_size | tl | trunc | '+' | '-' | '*' | 'div' | 'rem' | 'band' | 'bor' | 'bxor' | 'bnot' | 'bsl' | 'bsr' | '>' | '>=' | '<' | '=<' | '=:=' | '==' | '=/=' | '/=' | self
    BoolFunction ::= is_atom | is_float | is_integer | is_list | is_number | is_pid | is_port | is_reference | is_tuple | is_map | map_is_key | is_binary | is_function | is_record | 'and' | 'or' | 'not' | 'xor' | 'andalso' | 'orelse'

    举例
    1.
    [
    {  
        '$1',
        [{'==', gandalf, {element, 1, '$1'}},{'>=',{size, '$1'},2}],
        [{element,2,'$1'}]
    }
    ]
    把所有元组标记为 $1
    满足全部条件
        1. 元组的第一个元素 {element, 1, '$1'} == gandalf
        2. 元组的长度 {size, '$1'} >= 2
    最后返回的结果 为 元组的第二个元素 {element,2,'$1'}

    2.
    [
    {
        {'_',merry,'_'},
        [],
        ['$_']
    },
    {
        {'_',pippin,'_'},
        [],
        ['$_']
    }
    ]

    当有多个匹配时， 满足一个条件即可被检索出作为结果的一个元素
    第一部分
        匹配第一和第三个字段为任意结构， 中间为 merry的record
        没有匹配条件
        返回record
    第二部分同理

    ```
