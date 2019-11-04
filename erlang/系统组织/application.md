# Generic OTP application functions

In OTP, application denotes a component implementing some specific functionality, that can be started and stopped as a unit, and that can be reused in other systems. This module interacts with application controller, a process started at every Erlang runtime system.

This module contains functions for controlling applications (for example, starting and stopping applications), and functions to access information about applications (for example, configuration parameters).

**An application is defined by an application specification.** The specification is normally located in an application resource file named Application.app, where Application is the application name. For details about the application specification, see app(4).

This module can also be viewed as a behaviour for an application implemented according to the OTP design principles as a supervision tree. The definition of how to start and stop the tree is to be located in an application callback module, exporting a predefined set of functions.

# Application resource file.
The application resource file specifies the resources an application uses, and how the application is started. There must always be one application resource file called Application.app for each application Application in the system.

The file is read by the application controller when an application is loaded/started. It is also used by the functions in systools, for example when generating start scripts.

## File Syntax
**The application resource file is to be called Application.app, where Application is the application name. The file is to be located in directory ebin for the application.**

The file must contain a single Erlang term, which is called an application specification:

```erlang
% {application, Name, list of specific description}
{application, Application,
  [{description,  Description},
   {id,           Id},
   {vsn,          Vsn},
   {modules,      Modules},
   {maxP,         MaxP},
   {maxT,         MaxT},
   {registered,   Names},
   {included_applications, Apps},
   {applications, Apps},
   {env,          Env},
   {mod,          Start},
   {start_phases, Phases},
   {runtime_dependencies, RTDeps}]}.

applications
    All applications that must be started before this application is allowed to be started. systools uses this list to generate correct start scripts. Defaults to the empty list, but notice that all applications have dependencies to (at least) Kernel and STDLIB.

mod
    Specifies the application callback module and a start argument, see application(3).
    Key mod is necessary for an application implemented as a supervision tree, otherwise the application controller does not know how to start it. mod can be omitted for applications without processes, typically code libraries, for example, STDLIB.

start_phases
    A list of start phases and corresponding start arguments for the application. If this key is present, the application master, in addition to the usual call to Module:start/2, also calls Module:start_phase(Phase,Type,PhaseArgs) for each start phase defined by key start_phases. Only after this extended start procedure, application:start(Application) returns.

runtime_dependencies
    A list of application versions that the application depends on. An example of such an application version is "kernel-3.0". Application versions specified as runtime dependencies are minimum requirements. That is, a larger application version than the one specified in the dependency satisfies the requirement. For information about how to compare application versions, see section Versions in the System Principles User's Guide.

```


## The process of starting an application

```js
    start(Application) -> ok | {error, Reason}
    start(Application, Type) -> ok | {error, Reason}
```

Starts Application. If it is not loaded, the application controller first loads it using load/1. It ensures that any included applications are loaded, but does not start them. That is assumed to be taken care of in the code for Application.

The application controller checks the value of the application specification key **applications**, to ensure that all applications needed to be started before this application are running. Otherwise, {error,{not_started,App}} is returned, where App is the name of the missing application.

The application controller then creates an **application master** for the application. The application master becomes the group leader of all the processes in the application. I/O is forwarded to the previous group leader, though, this is just a way to identify processes that belong to the application. Used for example to find itself from any process, or, reciprocally, to kill them all when it terminates.

The application master starts the application by calling the application callback function **Module:start/2** as defined by the application specification key **mod**.

**Type -> Restart strategy**
Argument Type specifies the type of the application. If omitted, it defaults to **temporary**.
**Priority Order : permanent -> transient -> temporary**
If a **permanent** application terminates,
    all other applications and the entire Erlang node are also terminated. the application is so dominant.
If a **transient** application terminates with Reason == normal,
    this is reported but no other applications are terminated.
If a transient application terminates abnormally,
    all other applications and the entire Erlang node are also terminated.
If a temporary application terminates,
    this is reported but no other applications are terminated.

Notice that an application can always be stopped explicitly by calling stop/1. Regardless of the type of the application, no other applications are affected.
Notice also that the transient type is of little practical use, because when a supervision tree terminates, the reason is set to shutdown, not normal.

**Module:start/2**
```js
    Module:start(StartType, StartArgs) -> {ok, Pid} | {ok, Pid, State} | {error, Reason}

```
This function is called whenever an application is started using start/1,2, and is to start the processes of the application.
If the application is structured according to the OTP design principles as a supervision tree, this means starting the top supervisor of the tree.

**StartType** defines the type of start:
    normal
        if it is a normal startup.
    normal also
        if the application is distributed and started at the current node because of a failover from another node, and the application specification key start_phases == undefined.
    {takeover,Node}
        if the application is distributed and started at the current node because of a takeover from Node, either because takeover/2 has been called or because the current node has higher priority than Node.
    {failover,Node}
        if the application is distributed and started at the current node because of a failover from Node, and the application specification key start_phases /= undefined.

**StartArgs** is the StartArgs argument defined by the application specification key mod.

The function is to return {ok,Pid} or {ok,Pid,State}, where Pid is the pid of the top supervisor and State is any term.
If omitted, State defaults to []. If the application is stopped later, State is passed to Module:prep_stop/1.
