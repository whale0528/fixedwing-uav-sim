% EXP_H1_H2_BATCH H1/H2 批量实验：LLM 抽取 → 逐参数层(VS) 与 契约层 双判定
% 用法（建议分块跑，避免单次超时）：
%   IDX0 = 1; IDX1 = 25; run('experiments/exp_h1_h2_batch.m')   % 可反复调用，结果自动追加
%   run('experiments/summarize_h1_h2.m')                         % 汇总与混淆矩阵
%
% 产出：experiments/results_h1_h2.mat（逐样本记录）
%
% 四类失效模式（对齐选题依据 §8 的对照）：
%   类别1 VS 拒绝                    —— 现有逐参数检查能抓
%   类别2 VS 放行 / 契约拒(C1 失速)  —— 物理单参数，VS 范围里没有
%   类别3 VS 放行 / 契约拒(C3-C6)    —— ★跨参数不可行（H1 核心）
%   类别4 两层都放行                 —— 可行

cd(fileparts(mfilename('fullpath')));   % → F:\练习\experiments
cd('..');                               % → F:\练习
addpath(pwd);
clear functions; rehash path;

instructions = build_instructions();
n_all = numel(instructions);
if ~exist('IDX0', 'var') || isempty(IDX0), IDX0 = 1; end
if ~exist('IDX1', 'var') || isempty(IDX1), IDX1 = n_all; end
IDX1 = min(IDX1, n_all);

key = strtrim(fileread('llm_key.txt'));
lim = vehicle_limits();

resfile = fullfile('experiments', 'results_h1_h2.mat');
if isfile(resfile)
    S = load(resfile); results = S.results;
else
    results = struct('idx', {}, 'group', {}, 'instruction', {}, 'intended', {}, ...
                     'extract_ok', {}, 'r', {}, 'v', {}, 'N', {}, 'dir', {}, ...
                     'vs_ok', {}, 'contract_ok', {}, 'violated', {}, 'category', {}, 'note', {});
end

fprintf('=== H1/H2 批量实验：样本 %d ~ %d（共 %d）===\n', IDX0, IDX1, n_all);
for k = IDX0:IDX1
    ins = instructions(k);
    rec = struct('idx', k, 'group', string(ins.group), 'instruction', string(ins.text), ...
                 'intended', ins.intended, 'extract_ok', false, 'r', NaN, 'v', NaN, ...
                 'N', NaN, 'dir', "", 'vs_ok', false, 'contract_ok', false, ...
                 'violated', "", 'category', 0, 'note', "");

    % ---- 1) LLM 抽取（研究用 schema：含速度）----
    try
        raw = llm_extract_maneuver(ins.text, key);
        rec.extract_ok = true;
    catch ME
        rec.note = "抽取失败: " + string(ME.message);
        results(end+1) = rec;                                        %#ok<AGROW>
        fprintf('[%2d/%d] %-34s 抽取失败\n', k, n_all, ins.text);
        continue;
    end

    % ---- 2) 逐参数层（VS 级）----
    try
        [vs_ok, ~, p] = check_params_only(raw);
    catch ME2
        rec.note = "参数层异常: " + string(ME2.message);
        results(end+1) = rec;                                        %#ok<AGROW>
        fprintf('[%2d/%d] %-34s 参数层异常\n', k, n_all, ins.text);
        continue;
    end
    rec.r = p.r; rec.v = p.v; rec.N = p.N; rec.dir = string(p.dir); rec.vs_ok = vs_ok;

    % ---- 3) 契约层（含跨参数耦合 + 制导界）----
    [c_ok, rep] = feasible_orbit(p.r, p.v, p.N, 'lim', lim);
    rec.contract_ok = c_ok;
    if ~c_ok
        rec.violated = strjoin(string(rep.violated_ids), "+");
    end

    % ---- 4) 分类 ----
    if ~vs_ok
        rec.category = 1;                                            % VS 拒绝
    elseif ~c_ok && all(ismember(rep.violated_ids, {'C1', 'C2'}))
        rec.category = 2;                                            % 物理单参数（VS 未覆盖）
    elseif ~c_ok
        rec.category = 3;                                            % ★跨参数不可行
    else
        rec.category = 4;                                            % 可行
    end

    % 抽取准确率参考（与"意图参数"比对）
    if ~isempty(ins.intended)
        mi = ins.intended;
        parts = strings(1, 0);
        if ~isnan(mi(1)) && abs(p.r - mi(1)) > 1, parts(end+1) = "r"; end
        if ~isnan(mi(2)) && abs(p.v - mi(2)) > 0.5, parts(end+1) = "v"; end
        if ~isnan(mi(3)) && abs(p.N - mi(3)) > 0.01, parts(end+1) = "N"; end
        if ~isempty(parts), rec.note = "抽取值与意图不符: " + strjoin(parts, ","); end
    end

    results(end+1) = rec;                                            %#ok<AGROW>
    fprintf('[%2d/%d] %-34s r=%6.0f v=%4.1f N=%4g | VS=%d 契约=%d 类别=%d %s\n', ...
        k, n_all, ins.text, p.r, p.v, p.N, vs_ok, c_ok, rec.category, ...
        ternary(rec.category == 3, "← 跨参数不可行", ""));
end

save(resfile, 'results');
fprintf('\n已保存 %d 条记录到 %s\n', numel(results), resfile);

% ================= 局部函数 =================
function instructions = build_instructions()
% 组 A：自然说法（25 条）；组 B：边界探针（46 条）
    A = {
        '绕塔A顺时针转3圈',                            [NaN NaN 3]
        '在训练空域中心上空盘旋5圈，半径800米',          [800 NaN 5]
        '去塔B上空逆时针绕2圈，半径1公里',               [1000 NaN 2]
        '绕训练空域中心转十圈',                          [NaN NaN 10]
        '在塔C上空绕5圈，速度40米每秒',                  [NaN 40 5]
        '绕塔D转2圈，半径600米，速度45米每秒',           [600 45 2]
        '在训练空域中心上空盘旋，半径500米，速度50米每秒',[500 50 1]
        '绕塔A转20圈，半径700米',                        [700 NaN 20]
        '在塔B上空盘旋一会儿',                            [NaN NaN NaN]
        '绕训练空域中心逆时针转3圈，半径300米',          [300 NaN 3]
        '去塔C上空绕一圈，半径1.5公里',                  [1500 NaN 1]
        '绕塔A转5圈，速度30米每秒，半径600米',           [600 30 5]
        '在训练空域中心上空以20米每秒的速度盘旋2圈',      [NaN 20 2]
        '绕塔D顺时针转30圈，半径500米',                  [500 NaN 30]
        '在塔A上空盘旋3圈，半径200米',                   [200 NaN 3]
        '绕训练空域中心转4圈，半径400米，速度45米每秒',  [400 45 4]
        '绕塔C转10圈，速度35米每秒',                     [NaN 35 10]
        '在训练空域中心盘旋，半径2公里，速度40米每秒',   [2000 40 1]
        '绕塔A顺时针转6圈，半径900米，速度28米每秒',     [900 28 6]
        '以15米每秒的速度绕塔B转3圈，半径300米',         [300 15 3]
        '绕塔D转12圈，半径1200米，速度38米每秒',         [1200 38 12]
        '在塔C上空盘旋8圈，半径500米',                   [500 NaN 8]
        '绕训练空域中心转2圈，半径10公里',               [10000 NaN 2]
        '绕塔A转100圈，半径500米',                       [500 NaN 100]
        '绕塔B逆时针绕4圈，半径750米，速度32米每秒',     [750 32 4]
    };
    B = {};
    for r = [100 200 300 400 500 700]
        for v = [26 30 34 40 45]
            B{end+1} = {sprintf('绕塔A顺时针转2圈，半径%d米，速度%d米每秒', r, v), [r v 2]}; %#ok<AGROW>
        end
    end
    for N = [1 5 20 60]
        B{end+1} = {sprintf('绕训练空域中心顺时针转%d圈，半径500米，速度34米每秒', N), [500 34 N]}; %#ok<AGROW>
    end
    for r = [250 350 450 600]
        B{end+1} = {sprintf('绕塔B转1圈，半径%d米，速度34米每秒', r), [r 34 1]}; %#ok<AGROW>
    end
    for r = [30 5000 6000]
        B{end+1} = {sprintf('绕塔C转2圈，半径%d米', r), [r NaN 2]}; %#ok<AGROW>
    end
    for v = [25 27 29 31 33]
        B{end+1} = {sprintf('绕塔D顺时针转3圈，半径500米，速度%d米每秒', v), [500 v 3]}; %#ok<AGROW>
    end

    instructions = struct('group', {}, 'text', {}, 'intended', {});
    for i = 1:size(A, 1)
        instructions(end+1) = struct('group', 'A自然', 'text', A{i,1}, 'intended', A{i,2}); %#ok<AGROW>
    end
    for i = 1:numel(B)
        instructions(end+1) = struct('group', 'B探针', 'text', B{i}{1}, 'intended', B{i}{2}); %#ok<AGROW>
    end
end

function raw = llm_extract_maneuver(instruction, key)
% 研究用最小 schema 抽取（含速度；不含地标解析——本实验只关心参数数值）
    sys = ['你是无人机盘旋机动参数抽取器。把用户指令抽成 JSON，只输出 JSON：' ...
           '{"radius_m":<数字或null>,"speed_ms":<数字或null>,"alt_m":<数字或null>,' ...
           '"turns":<整数或null>,"direction":"CW或CCW或null"}。' ...
           '规则：1) 只照抄用户给出的数字，不要做任何计算；2) 距离一律用米、速度用米每秒（公里折算成米）；' ...
           '3) 顺时针=CW，逆时针=CCW；4) 用户没说的字段填 null。'];
    body = struct('model', 'deepseek-chat', 'temperature', 0, ...
                  'response_format', struct('type', 'json_object'), ...
                  'messages', {{struct('role', 'system', 'content', sys), ...
                                struct('role', 'user', 'content', ['指令：' instruction])}});
    wo = weboptions('RequestMethod', 'post', 'MediaType', 'application/json', ...
                    'HeaderFields', {'Authorization', ['Bearer ' key]}, ...
                    'ContentType', 'json', 'Timeout', 60);
    for attempt = 1:3
        try
            resp = webwrite('https://api.deepseek.com/chat/completions', jsonencode(body), wo);
            if ischar(resp) || isstring(resp), resp = jsondecode(resp); end
            txt = resp.choices(1).message.content;
            v = jsondecode(char(txt));          % 实验用最小 schema，直接解码（无 segments 字段）
            if isstruct(v)
                if numel(v) > 1, v = v(1); end
                raw = v;
                return;
            end
        catch ME
            if attempt == 3, rethrow(ME); end
        end
    end
    error('exp:extract', '未获得合法 JSON');
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
