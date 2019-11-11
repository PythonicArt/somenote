刷怪
怪物数据存储于场景进程里， #map_object{type = monster}
1. 申请一个uid， 根据配置生成一个map_object实例
2. 存入场景进程， 通知所有玩家有怪刷出

怪物ai过程
定时(500毫秒)触发检查怪物ai, 更新怪物状态, 决定怪物的下一步操作
决定怪物走动， 释放技能， 死亡等等

逻辑流程
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
存于ets, 将ets标识存于进程字典

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
            %% 一个ai时间到不了或者前方有阻挡
            %% 计算一个可以移动的方向
            NewDir = ai_move_dir(Site, DestSite, Speed),
            %% 根据新的方向按速度前进
            NextSite = ai_move_dest(Site, NowDir, Speed),
            %% 修改位置， 刷新ai时间
            NewMonState = MonState#mon_state{next_work_time = Now + AiTime},
            {NewMonState, NewMonObj}
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
            设 角度大小为 A, 起点为(X0, Z0), 位移值为 M(这里通过 速度和时间可以计算)
            则 终点坐标为  (X0 + M * cosA, Z0 + M * sinA)

            角度计算 (X0, Z0), (X1, Z1)
            sinA = (Z1-Z0)/Dis
            角度大小 A = asin((Z1 - Z0)/Dis)
            由于反正弦函数的值域， -90 - 90, 需要做转换,
            当方向向右时， X1 > X0时,  2 * pi + A, sin(A) = sin(2*pi + A)
                如sinA>0, 即Z1>Z0, 实际大小为: A, 为正值, 图像上，方向在第第一象限
                如sinA<0, 即Z1<Z0, 通过arcsin算出的是负角度, 2 * pi + A刚好转化 2*pi - |A| 为正值, 从图像上来看, 方向在第四象限

            当方向向左时， X1 < X0时, pi - A, sin(A) = sin(pi - A)
                如sinA>0, 即Z1>Z0, 则实际大小应该是其补角, pi-A, 为正值, 图像上，方向在第二象限
                如sinA<0, 即Z1<Z0, 通过arcsin算出的也是负角度, pi-A刚好转化 pi + |A| 为正值, 从图像上来看， 方向在第三象限

```
