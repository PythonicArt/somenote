# Generic supervisor behavior.

This behavior module provides a supervisor, a process that supervises other processes called child processes. A child process can either be another supervisor or a worker process. Worker processes are normally implemented using one of the gen_event, gen_server, or gen_state behaviors.
A supervisor implemented using this module has a standard set of interface functions and include functionality for tracing and error reporting.
Supervisors are used to build a hierarchical process structure called a supervision tree, a nice way to structure a fault-tolerant application.

The supervisor is responsible for starting, stopping, and monitoring its child processes. The basic idea of a supervisor is that it must keep its child processes alive by restarting them when necessary.

The children of a supervisor are defined as a list of child specifications.
1. When the supervisor is started, the child processes are started in order from left to right according to this list.
2. When the supervisor terminates, it first terminates its child processes in reversed start order, from right to left.
Apparently, it is a heap.


# Start a supvisor
```js
    start_link(Module, Args) -> startlink_ret()
    start_link(SupName, Module, Args) -> startlink_ret()

    startlink_ret() =
        {ok, pid()} | ignore | {error, startlink_err()}
    startlink_err() =
        {already_started, pid()} | {shutdown, term()} | term()
    sup_name() =
        {local, Name :: atom()} |
        {global, Name :: atom()} |
        {via, Module :: module(), Name :: any()}
```
Creates a supervisor process as part of a supervision tree. For example, the function ensures that the supervisor is linked to the calling process (its supervisor).

The created supervisor process calls **Module:init/1** to find out about restart strategy, maximum restart intensity, and child processes. To ensure a synchronized startup procedure, start_link/2,3 does not return until Module:init/1 has returned and all child processes have been started.

If no name is provided, the supervisor is not registered.
Module is the name of the callback module.
Args is any term that is passed as the argument to Module:init/1.

## **return value**
{ok,Pid}
    If the supervisor and its child processes are successfully created (that is, if all child process start functions return {ok,Child}, {ok,Child,Info}, or ignore), the function returns {ok,Pid}, where Pid is the pid of the supervisor.

{error,{already_started,Pid}}
    If there already exists a process with the specified SupName, the function returns {error,{already_started,Pid}}, where Pid is the pid of that process.

ignore
    If Module:init/1 returns ignore, this function returns ignore as well, and the supervisor terminates with reason normal.

{error, Term}
    If Module:init/1 fails or returns an incorrect value, this function returns {error,Term}, where Term is a term with information about the error, and the supervisor terminates with reason Term.

{error, {shutdown, Reason}}
    If any child process start function fails or returns an error tuple or an erroneous value, the supervisor first terminates all already started child processes with reason shutdown and then terminate itself and returns {error, {shutdown, Reason}}.

## **Module:init(Args)**
```js
Module:init(Args) -> Result
    Args = term()
    Result = {ok,{SupFlags,[ChildSpec]}} | ignore
    SupFlags = sup_flags()
    ChildSpec = child_spec()
```

Whenever a supervisor is started using start_link/2,3, this function is called by the new process to find out about restart strategy, maximum restart intensity, and child specifications.

Args is the Args argument provided to the start function.
SupFlags is the supervisor flags defining the restart strategy and maximum restart intensity for the supervisor.
[ChildSpec] is a list of valid child specifications defining which child processes the supervisor must start and monitor.

```js
sup_flags() = #{strategy => strategy(),         % optional
                intensity => non_neg_integer(), % optional
                period => pos_integer()}        % optional
```

## strategy
A supervisor can have one of the following restart strategies specified with the strategy key in the above map:

    one_for_one(default) -
        If one child process terminates and is to be restarted, only that child process is affected. This is the default restart strategy.

    one_for_all -
        If one child process terminates and is to be restarted, all other child processes are terminated and then all child processes are restarted.

    rest_for_one -
        If one child process terminates and is to be restarted, the 'rest' of the child processes (that is, the child processes after the terminated child process in the start order) are terminated. Then the terminated child process and all child processes after it are restarted.

    simple_one_for_one -
        A simplified one_for_one supervisor, where all child processes are dynamically added instances of the same process type, that is, running the same code.

## intensity & period
It only allow it's child process to resart A times(intensity) **at the most** in B secondes(period).

To prevent a supervisor from getting into an infinite loop of child process terminations and restarts, a maximum restart intensity is defined using two integer values specified with keys intensity and period in the above map.
Assuming the values MaxR for intensity and MaxT for period, then, if more than MaxR restarts occur within MaxT seconds, the supervisor terminates all child processes and then itself. The termination reason for the supervisor itself in that case will be shutdown. intensity defaults to 1 and period defaults to 5.

## child specification

The type definition of a child specification is as follows:
```js
child_spec() = #{id => child_id(),       % mandatory = term(), Not a pid().
                 start => mfargs(),      % mandatory
                 restart => restart() ,  % optional, = permanent | transient | temporary
                 shutdown => shutdown(), % optional, brutal_kill | timeout()
                 type => worker(),       % optional = supervisor | worker(default)
                 modules => modules()}   % optional

     id
         id is used to identify the child specification internally by the supervisor.
         The id key is mandatory.
         Notice that this identifier on occations has been called "name". As far as possible, the terms "identifier" or "id" are now used but to keep backward compatibility, some occurences of "name" can still be found, for example in error messages.

    start
        // **The child process is created in the start fun**
        start defines the function call used to start the child process.
        It must be a module-function-arguments tuple {M,F,A} used as apply(M,F,A).
        The start function must create and link to the child process, and must return {ok,Child} or {ok,Child,Info}, where Child is the pid of the child process and Info any term that is ignored by the supervisor.
        The start function can also return ignore if the child process for some reason cannot be started, in which case the child specification is kept by the supervisor (unless it is a temporary child) but the non-existing child process is ignored.
        If something goes wrong, the function can also return an error tuple {error,Error}.
        Notice that the start_link functions of the different behavior modules fulfill the above requirements.
        The start key is mandatory.

    type
        type specifies if the child process is a supervisor or a worker.
        The type key is optional. If it is not specified, it defaults to worker.

    restart    
        restart defines when a terminated child process must be restarted.
        A permanent child process is always restarted, this is also limited by the SupFlags.
        A temporary child process is never restarted (even when the supervisor's restart strategy is rest_for_one or one_for_all and a sibling's death causes the temporary process to be terminated).
        A transient child process is restarted only if it terminates abnormally, that is, with another exit reason than normal, shutdown, or {shutdown,Term}.
        The restart key is optional. If it is not specified, it defaults to permanent.

    shutdown    
        shutdown defines how a child process must be terminated when the supervisor want to terminate it.
        It is used to supply a way for some operation that is done in child process when the child need to be killed.
        // brutal_kill
        brutal_kill means that the child process is unconditionally terminated using exit(Child,kill).
        // timeout
        An integer time-out value means that the supervisor tells the child process to terminate by calling exit(Child,shutdown) and then wait for an exit signal with reason shutdown back from the child process. If no exit signal is received within the specified number of milliseconds, the child process is unconditionally terminated using exit(Child,kill).
        // default
        The shutdown key is optional. If it is not specified, it defaults to 5000 if the child is of type worker and it defaults to infinity if the child is of type supervisor.

```

**Notice** that when the restart strategy is simple_one_for_one, the list of child specifications must be a list with one child specification only. (The child specification identifier is ignored.)
No child process is then started during the initialization phase, but all children are assumed to be started dynamically using start_child/2.
It is very suitable for the system in which a role process (child) is created  when a network connection has just created.

# Children Management
如果知道监控树根节点， 就能通过supervisor模块进行子节点的管理
SupRef can be any of the following:
    * The pid
    * Name, if the supervisor is locally registered
    * {Name,Node}, if the supervisor is locally registered at another node
    * {global,Name}, if the supervisor is globally registered
    * {via,Module,Name}, if the supervisor is registered through an alternative process registry

启动
```js
    start_child(SupRef, ChildSpec) -> startchild_ret()
    startchild_ret() =
        {ok, Child :: child()} |
        {ok, Child :: child(), Info :: term()} |
        {error, startchild_err()}
    startchild_err() =
        already_present | {already_started, Child :: child()} | term()
```
    Dynamically adds a child specification to supervisor SupRef, which starts the corresponding child process.

    For a simple_one_for_one supervisor, the child specification defined in Module:init/1 is used, and ChildSpec must instead be an arbitrary list of terms List. The child process is then started by appending List to the existing start function arguments, that is, by calling apply(M, F, A++List), where {M,F,A} is the start function defined in the child specification.
    因为 simple_one_for_one 是所有子进程都执行同一份代码， 唯一地区别只能是传入启动函数的参数不同， 添加这样的一个子进程时， 只需提供额外的参数即可

    {error,already_present}
        If there already exists a child specification with the specified identifier, ChildSpec is discarded, and the function returns {error,already_present} or {error,{already_started,Child}}, depending on if the corresponding child process is running or not.
    {ok,Child}
        If the child process start function returns {ok,Child} or {ok,Child,Info}, the child specification and pid are added to the supervisor and the function returns the same value.
    {ok,undefined}
        If the child process start function returns ignore, the child specification is added to the supervisor (unless the supervisor is a simple_one_for_one supervisor, see below), the pid is set to undefined, and the function returns {ok,undefined}.
        For a simple_one_for_one supervisor, when a child process start function returns ignore, the functions returns {ok,undefined} and no child is added to the supervisor.

停止
```js
    terminate_child(SupRef, Id) -> Result
```
    Tells supervisor SupRef to terminate the specified child.

    If the supervisor is not simple_one_for_one, Id must be the child specification identifier.
    If the supervisor is simple_one_for_one, Id must be the pid() of the child process.(because the children have not a unique identifier in addition to pid())

    The process, if any, is terminated and, unless it is a temporary child, the child specification is kept by the supervisor. The child process can later be restarted by the supervisor. The child process can also be restarted explicitly by calling restart_child/2. Use delete_child/2 to remove the child specification.

    If the child is temporary, the child specification is deleted as soon as the process terminates.
    This means that delete_child/2 has no meaning and restart_child/2 cannot be used for these children.

    In simple_one_for_one:
        {error,not_found}
            If the specified process is alive, but is not a child of the specified supervisor, the function returns {error,not_found}.
        {error,simple_one_for_one}
         If the child specification identifier is specified instead of a pid(), the function returns {error,simple_one_for_one}.

    If successful, the function returns ok.
    If there is no child specification with the specified Id, the function returns {error,not_found}.

移除
    ```js
        delete_child(SupRef, Id) -> Result
    ```
    Tells supervisor SupRef to delete the child specification identified by Id. The corresponding child process must not be running. Use terminate_child/2 to terminate it.

    You can restart a child when it is terminted, but when it is deleted, you are not able to do that.

计数
    ```js
        count_children(SupRef) -> PropListOfCounts
        Types
        SupRef = sup_ref()
        PropListOfCounts = [Count]
        Count =
            {specs, ChildSpecCount :: integer() >= 0} |
            {active, ActiveProcessCount :: integer() >= 0} |
            {supervisors, ChildSupervisorCount :: integer() >= 0} |
            {workers, ChildWorkerCount :: integer() >= 0}
    ```
    Returns a property list (see proplists) containing the counts for each of the following elements of the supervisor's child specifications and managed processes:

    specs
        The total count of children, dead or alive.

    active
        The count of all actively running child processes managed by this supervisor. For a simple_one_for_one supervisors, no check is done to ensure that each child process is still alive, although the result provided here is likely to be very accurate unless the supervisor is heavily overloaded.

    supervisors
        The count of all children marked as child_type = supervisor in the specification list, regardless if the child process is still alive.

    workers
        The count of all children marked as child_type = worker in the specification list, regardless if the child process is still alive.
