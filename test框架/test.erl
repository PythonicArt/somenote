-module (test).
-compile(export_all).

case_get_xxxx_data()->
    [
        {
            mf,{Mod, Fun}
        },
        {
            cases, [get_case1(), get_case2()...]
        }
    ].

get_case1() ->
    Fun = fun() ->
        before_test(),
        [
            {args, [Arg1, Arg2]},
            {config, [{pt, 1}]},
            {expect, Expect},
            {check, CheckFun}
        ]
    end,
    Fun.

test(TestConfig)
    {_, {M, F}} = lists:keyfind(mf, 1, TestConfig),
    {_, Tests} = lists:keyfind(cases, 1, TestConfig),
    Fun = fun({CaseId, Case}, {True, False}) ->
        Result = test_(M, F, Case),
        case Result of
            passed ->
                {[CaseId|True], False};
            _ ->
                {True, [CaseId|False]}
        end
    end,
    Num = length(Tests),
    {True, False} = lists:foldl(Fun, {[], []}, lists:zip(lists:seq(1, Num), Tests)),
    TrueNum = length(True),
    FalseNum = length(False),
    if
        FalseNum > 0 ->
            io:format("PassedNum is ~p ~n", [TrueNum]),
            io:format("UnPassedNum is ~p ~n", [FalseNum]),
            [io:format("Unpassed caseId are ~w ~n", [False])],
            unpassed;
        true ->
            io:format("All Test passed!!!!!!!!!!!!!!!!"),
            pass
    end.

test_(M, F, TestCase)->
    Case = TestCase(),
    {_, Args} = lists:keyfind(args, 1, Case),
    {_, Configs} = lists:keyfind(config, 1, Case),
    {_, PreExpect} = lists:keyfind(expect, 1, Case),
    {_, Check} = lists:keyfind(check, 1, Case),
    {_, Type} = lists:keyfind(type, 1, Case),
    case is_function(PreExpect) of
        true ->
            Expect = PreExpect();
        _ ->
            Expect = PreExpect
    end,
    try
        R = exec_main(M, F, Args, Type),
        {_, OpenPt} = lists:keyfind(pt, 1, Configs),
        ?IF(Pt =/= false, pt_value_thing(Args, Case)),
        ExpectList = Check(),
        ?IF(check_expect([{Expect, R}|ExpectList]), passed, false);
    catch
        {error, Code}->
            try
                Expect = Code,
                passed
            catch
                _EType:_Err0 ->
                    pt_value_thing(Args, Case),
                    % insert_false_info(),
                    false
            end;
        _EType:_Error ->
            pt_value_thing(Args, Case),
            Stack = erlang:get_stacktrace(),
            io:format("~p ~n", [Stack]),
            false
    end.


check_expect(ExpectList) ->
    lists:all(fun({Left, Right}) Left =:= Right -> end, ExpectList).

exec_main(M, F, Args, role)->
    [RoleId|TrueArg] = Args,
    Fun = fun()->
        try
            apply(M, F, Args)
        catch
            {error, Code} ->
                {error, Code};
            _EType:_Error ->
                StackTrace = erlang:get_stacktrace(),
                io:format("~p ~n", [StackTrace]),
                false
        end
    end,
    cast_to_role_apply_fun(RoleId, Fun).
exec_main(M, F, Args, _)->
    Fun = fun()->
        try
            apply(M, F, Args)
        catch
            {error, Code} ->
                {error, Code};
            _EType:_Error ->
                StackTrace = erlang:get_stacktrace(),
                io:format("~p ~n", [StackTrace]),
                false
        end
    end.
