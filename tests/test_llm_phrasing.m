% TEST_LLM_PHRASING 说法鲁棒性清单（脚本版）
% 逐条把"用户可能说的话"喂给 llm2route，再过 check_route_spec，自动对期望做判定。
% 用法：命令窗口 run('F:\练习\tests\test_llm_phrasing.m')
% 期望类型：
%   'orbit'  期望存在满足指定圆心/半径/方向/圈数的 orbit 段
%   'goto'   期望最后一段是 goto 到指定坐标
%   'reject' 期望被安全门拒绝（ok=false）
%   'clip'   期望某字段被钳制到指定值
%   'record' 只记录（模糊/无法表达的说法，看它怎么兜底）

cd(fileparts(mfilename('fullpath')));
cd('..');
addpath(pwd);
clear functions;
rehash path;

if ~isfile('llm_key.txt') || contains(fileread('llm_key.txt'), '请把这一行')
    error('未配置 llm_key.txt，无法做在线鲁棒性测试');
end
lm = readtable('landmarks.xlsx');
lm_names = string(lm.name)';

C = { ...
  '向北飞2000米后绕训练空域中心半径500米顺时针转两圈',        'orbit',  struct('center',[8000 2000],'r',500,'dir','CW','turns',2); ...
  '绕训练空域中心转十圈',                                      'orbit',  struct('center',[8000 2000],'r',500,'dir','','turns',10); ...
  '在塔B上空盘旋5圈，半径600米，逆时针',                        'orbit',  struct('center',[5500 5000],'r',600,'dir','CCW','turns',5); ...
  '去塔A上空逆时针绕3圈，半径800米',                            'orbit',  struct('center',[1500 1500],'r',800,'dir','CCW','turns',3); ...
  '向北飞3公里后返回起飞点',                                    'goto',   struct('xy',[0 0]); ...
  '先向正东飞5公里，再绕塔C顺时针两圈，半径1公里',              'orbit',  struct('center',[3500 6500],'r',1000,'dir','CW','turns',2); ...
  '飞到塔D然后绕它转两圈，半径800米',                           'orbit',  struct('center',[5500 7500],'r',800,'dir','','turns',2); ...
  '向北飞2000米以后绕训练空域中心转3圈再回来',                  'goto',   struct('xy',[0 0]); ...
  '去塔A看看',                                                  'goto',   struct('xy',[1500 1500]); ...
  '绕训练空域中心转100圈',                                      'clip',   struct('field','turns','value',50); ...
  '绕训练空域中心转2圈，半径100米',                              'clip',   struct('field','radius','value',400); ...
  '飞到火星',                                                   'reject', struct(); ...
  '去坐标北3000东2000那里绕500米两圈',                          'flag',   struct(); ...
  '绕训练空域中心飞个八字',                                      'record', struct(); ...
  '在训练空域中心上空盘旋一会儿',                                'record', struct(); ...
  '随便飞飞',                                                   'record', struct(); ...
};

R = {}; npass = 0; nfail = 0;
fprintf('=== 说法鲁棒性清单（%d 条） ===\n', size(C,1));
for i = 1:size(C,1)
    phrasing = C{i,1}; kind = C{i,2}; exp = C{i,3};
    try
        raw = llm2route(phrasing, 'Landmarks', lm_names);
        [plan, issues, ok] = check_route_spec(raw, lm);
        seg_str = seg_summary(plan.segments);
        [pass, note] = eval_case(kind, exp, plan, ok, plan.assumptions);
    catch ME
        seg_str = '（调用失败）'; issues = {ME.message}; ok = false;
        pass = false; note = ME.message;
    end
    if pass, npass = npass + 1; tag = 'PASS'; else, nfail = nfail + 1; tag = 'FAIL'; end
    fprintf('\n[%2d][%s] %s\n', i, tag, phrasing);
    fprintf('      期望: %s | 实际: %s\n', kind, seg_str);
    if ~strcmp(kind, 'record')
        fprintf('      判定: %s\n', note);
    end
    if ~isempty(issues)
        fprintf('      issues: %s\n', strjoin(issues, ' | '));
    end
end

fprintf('\n=== 汇总：%d 条判定中 %d 通过 / %d 失败（另有 %d 条仅记录） ===\n', ...
    npass+nfail, npass, nfail, size(C,1)-(npass+nfail));

% ================= 局部函数 =================
function s = seg_summary(segs)
    parts = {};
    for k = 1:numel(segs)
        g = segs{k};
        switch g{1}
            case 'orbit'
                parts{end+1} = sprintf('orbit(%.0f,%.0f r=%.0f %s %d圈)', g{2}, g{3}, g{4}, g{5}); %#ok<AGROW>
            case 'goto'
                h = g{2}(3);
                if isnan(h)
                    hs = '自由';
                else
                    hs = sprintf('%.0f°', h);
                end
                parts{end+1} = sprintf('goto(%.0f,%.0f h=%s)', g{2}(1), g{2}(2), hs); %#ok<AGROW>
            case 'line_to'
                parts{end+1} = sprintf('line_to(%.0f,%.0f)', g{2}); %#ok<AGROW>
            case {'line', 'exit_line'}
                parts{end+1} = sprintf('%s %.0fm', g{1}, g{2}); %#ok<AGROW>
            case 'turn_to'
                parts{end+1} = sprintf('turn_to %.0f°', g{2}); %#ok<AGROW>
        end
    end
    s = strjoin(parts, ' → ');
end

function [pass, note] = eval_case(kind, exp, plan, ok, assumptions)
    pass = false; note = '';
    switch kind
        case 'record'
            pass = true;                     % 仅记录：兜底或拒绝都算合理
            note = sprintf('ok=%d（仅记录）', ok);
        case 'flag'
            % 期望：通过校验，且把"用户给的是坐标"这类问题写进 assumptions
            has_flag = any(contains(string(assumptions), '坐标'));
            pass = ok && has_flag;
            note = sprintf('ok=%d, assumptions 提到坐标=%d', ok, has_flag);
        case 'reject'
            pass = ~ok;
            note = sprintf('ok=%d（期望 0）', ok);
        case 'orbit'
            if ok
                for k = numel(plan.segments):-1:1
                    g = plan.segments{k};
                    if strcmp(g{1}, 'orbit')
                        cok = isequal(g{2}, exp.center);
                        rok = g{3} == exp.r;
                        dok = isempty(exp.dir) || strcmp(g{4}, exp.dir);
                        tok = g{5} == exp.turns;
                        pass = cok && rok && dok && tok;
                        note = sprintf('圆心%s 半径%s 方向%s 圈数%s', tf(cok), tf(rok), tf(dok), tf(tok));
                        return;
                    end
                end
                note = '未找到 orbit 段';
            else
                note = '被安全门拒绝';
            end
        case 'goto'
            if ok
                g = plan.segments{end};
                pass = strcmp(g{1}, 'goto') && isequal(g{2}(1:2), exp.xy);
                note = sprintf('末段 = %s', g{1});
            else
                note = '被安全门拒绝';
            end
        case 'clip'
            if ok
                for k = 1:numel(plan.segments)
                    g = plan.segments{k};
                    if strcmp(g{1}, 'orbit') && strcmp(exp.field, 'turns')
                        pass = g{5} == exp.value; note = sprintf('圈数=%d（期望 %d）', g{5}, exp.value); return;
                    elseif strcmp(g{1}, 'orbit') && strcmp(exp.field, 'radius')
                        pass = g{3} == exp.value; note = sprintf('半径=%.0f（期望 %.0f）', g{3}, exp.value); return;
                    end
                end
                note = '未找到 orbit 段';
            else
                note = '被安全门拒绝';
            end
    end
end

function s = tf(b), if b, s = '✓'; else, s = '✗'; end, end
