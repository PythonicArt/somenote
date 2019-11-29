# 刷怪
怪物数据存储于场景进程里， #map_object{type = monster}
1. 申请一个uid， 根据配置生成一个map_object实例
2. 存入场景进程， 通知所有玩家有怪刷出

# 怪物ai过程
一个很短的定时间隔(比如300毫秒)触发检查怪物ai, 更新怪物状态, 决定怪物的下一步操作
决定怪物走动， 释放技能， 死亡等等

# 逻辑流程
1. 场景维护一个定时器， 定时检测ai状态
2. 定时器到， 遍历每一个mon_state 进行ai操作计算
3. ai计算得到该轮的动作并执行， 生成新的状态，如果已经死亡则删除， 否则 更新mon_state, 用于下轮ai检查

```erlang

-record(mon_state{
    object_id,
    object_type,
    tpl_id,

    state = normal, %%　normal, dead, back, reborn
    start_time, %% 状态开始时间
    is_walk, %% 是否正在行走
    next_work_time, %% 下一次ai时间

    sub_type,
    view_range,
    track_range,
    selected_skill,
    target,
    ...
})

mon_state是一个怪物的基本状态的实例,用于控制怪物的状态， 攻击目标， 攻击范围等
可以存于ets, 将ets标识存于进程字典

1. 移动
当前位置site, 目标位置 destSite, 移动速度 speed
do_move(MonState, MonObj) ->
    Site = current_site(),
    DestSite = dest_site(),
    Dis = distance(Site, DestSite),
    Speed = speed(),
    Angle = calc_angle(Site, DestSite),
    case Dis =< Speed * AiTime andalso check_move(Site, Angle, DestSite) of
        true ->
            %% 当一个ai时间内可以到达并且直线方向没有阻挡，修改到终点坐标， 移动完成
            % 修改移动状态为 normal, state = normal, is_walk = false
            move_stop(MonObject, DestSite);
        _ ->
            %% 一个ai时间到不了或者当前方向有阻挡(需要换方向)
            %% 计算一个可以移动的方向, 即 按照这个方向 以当前的速度前进的点 是可达的
            NewDir = ai_move_dir(Site, DestSite, Speed),
            %% 根据新的方向按速度前进
            NextSite = ai_move_dest(Site, NowDir, Speed),
            %% 修改位置， 刷新ai时间
            NewMonState = MonState#mon_state{next_work_time = Now + AiTime},
            {NewMonState, NewMonObj}
    end.

    ai_move_dir(Site, ToSite, Speed) ->
        Angle = calc_angle(Site, ToSite),
        DestSite = ai_move_dest(Site, Angle, Speed),
        TailSec = util:now_sec() rem 100 div 10,
        RotateDir = TailSec rem 2 == 0, %% 通过执行的时间来计算角度调整的方向， 顺时针或逆时针. 每十秒钟进行一次切换.保证移动的随机性
        % 开始逐步判断
        case ai_move_dir(Site, Angle, DestSite, Speed, 8, 1, RotateDir) of
            {ok, NewAngle} ->
                NewAngle;
            false ->
                Angle
        end.

    ai_move_dir(Site, Angle, DestSite, Speed, MaxCount, CurCount, RotateDir) when CurCount > MaxCount->
        % 超出了试探次数，没有可以移动的方向
        false;
    ai_move_dir(Site, Angle, DestSite, Speed, MaxCount, CurCount, RotateDir) ->
        case check_move(Site, Angle, DestSite) of
            true ->
                {ok, Angle};
            _ ->
                % 当前方向一步也移动不了, 换一个方向
                NextAngle = calc_new_angle(Angle, RotateDir),
                NewDestSite = move_dest(Site, NextAngle, Speed),
                ai_move_dir(Site, NextAngle, NewDestSite, Speed, MaxCount, Count +1, RotateDir)
        end.

    check_move(Site, Dir, ToSite)->
        {X, Y, Z} = ToSite,
        Distance = dis(Site, ToSite),
        do_check_move(Site, Dir, Distance, 0).

    % 检查出发点到终点的的途中是否有阻挡点, 从0开始前进， 直到前进距离大于需要的距离
    do_check_move(_Site, _Dir, Distance, NowDistance) when NowDistance >= Distance ->
        true;
    do_check_move(Site, Dir, Distance, NowDistance) ->
        NextDistance = min(Distance, NowDistance + ?GridWidth),
        {NX, NY, NZ} = calc_site_by_dis(Stie, Dir, Distance),
        case is_block(Nx, Ny, Nz) of
            true ->
                false;
            false ->
                do_check_move(Site, Dir, Distance, NowDistance)
        end.


2. 某方向的阻挡的判断
    从坐标点出发, 以前端格子大小为单位, 按方向前进到下一个格子, 如果该格子属于不可行区域， 则为阻挡点， 该方向不可行. 否则可行

3. 行走过程中方向的选择
    1. 初始以与目标位置的直线方向，如果可行， 则前进一步
    2. 如果不可行， 以当前方向 顺时针或是逆时针旋转45度, 计算下一个方向. 如果最后旋转到原方向， 则确定为没有可行走的方向， 下一个位置不可达

    坐标轴的建立
        横向x, 竖向z
        方向值  pi为单位， 放大1亿倍
        上  pi/2
        下  pi
        左  3*pi/2
        右  2*pi

    数学基础
        方向向量
            起点和终点连成的直线， 并且由起点指向终点
            这个方向与坐标轴的夹角是 形成的角度

            用角度来描述方向, 当知道方向(角度)后, 只要知道出发点和位移， 就可以确定终点的位置
            设 角度大小为 A, 起点为(X0, Z0), 位移值为 M(通过 速度和时间可以计算)
            则 终点坐标为  (X0 + M * cosA, Z0 + M * sinA)

            角度计算 (X0, Z0), (X1, Z1)
            sinA = (Z1-Z0)/Dis
            角度大小 A = asin((Z1 - Z0)/Dis)
            由于反正弦函数的值域， -90 <-> +90, 无法覆盖整个坐标轴方向, 需要做转换,
            当方向向右时， X1 > X0时,  2 * pi + A, sin(A) = sin(2*pi + A)
                如sinA>0, 即Z1>Z0, 实际大小为: A, 为正值, 图像上，方向在第第一象限
                如sinA<0, 即Z1<Z0, 通过arcsin算出的是负角度, 2 * pi + A刚好转化 2*pi - |A| 为正值, 从图像上来看, 方向在第四象限

            当方向向左时， X1 < X0时, pi - A, sin(A) = sin(pi - A)
                如sinA>0, 即Z1>Z0, 则实际大小应该是其补角, pi-A, 为正值, 图像上，方向在第二象限
                如sinA<0, 即Z1<Z0, 通过arcsin算出的也是负角度, pi-A刚好转化 pi + |A| 为正值, 从图像上来看， 方向在第三象限

    前提
        一个模型格子内全部都是可移动点， 如果有一个点不可移动， 则整个模型格子内的点都为阻挡点

    需要考虑清楚的问题
        移动单位是如何确定的?
            每次试探距离为 一个模型格子的宽度. 根据速度和ai时间决定一次前进的距离， 根据模型格子宽度逐一试探这一次前进是否可行

        目标点不可达, 如何处理?
            简要的过程
                优先按照当前位置到目标位置的直线前进， 通过试探逐一往前.
                如果中途无法前进， 即存在阻挡点， 则换一个方向前进一步。 进入到新的点时， 再从头开始，优先按照直线的方向前进。 直到到达终点.
            这样， 如果没到达终点， 就会一直调整方向进行试探

```
