function ok = confirm_route(plan, opt)
% CONFIRM_ROUTE 人工确认环（HITL）：LLM 回译 + 确定性清单 + 命令行 y/n
% plan : check_route_spec 的输出
% opt  : UseLLM（默认 true，调 LLM 复述；失败自动回退）
%        AutoYes（默认 false；true 时跳过提问直接确认，供脚本/测试使用）
% 返回 ok : 用户是否确认执行（只认 y/yes/是/确认）
%
% 设计依据（见《UAV与LLM两条技术路线总结.md》）：LLM 把计划回译成人话，人确认后才执行。
% 回译失败不影响确认——确定性清单始终打印。
    arguments
        plan (1,1) struct
        opt.UseLLM (1,1) logical = true
        opt.AutoYes (1,1) logical = false
    end

    fprintf('\n================ 计划确认（HITL）================\n');
    fprintf('将要执行的动作（共 %d 段）：\n', numel(plan.segments));
    for k = 1:numel(plan.segments)
        fprintf('  %d. %s\n', k, seg_line(plan.segments{k}));
    end

    if ~isempty(plan.assumptions)
        fprintf('LLM 的假设/提示：\n');
        for k = 1:numel(plan.assumptions)
            fprintf('  · %s\n', plan.assumptions{k});
        end
    end

    if opt.UseLLM
        txt = route2nl(plan);
        if ~isempty(txt)
            fprintf('LLM 复述：%s\n', txt);
        else
            fprintf('（LLM 复述不可用，已回退到上面的确定性清单）\n');
        end
    end

    if opt.AutoYes
        fprintf('（自动确认：AutoYes）\n');
        ok = true;
        fprintf('===============================================\n');
        return;
    end

    a = strtrim(lower(input('确认执行？(y/n): ', 's')));
    ok = any(strcmp(a, {'y', 'yes', '是', '确认', '好'}));
    if ok
        fprintf('已确认，开始执行。\n');
    else
        fprintf('已取消，不执行。\n');
    end
    fprintf('===============================================\n');
end

function s = seg_line(g)
% 单个动作的中文描述（含已解析坐标）
    switch g{1}
        case 'turn_to'
            s = sprintf('转向航向 %.0f°', g{2});
        case 'line'
            s = sprintf('沿当前航向直飞 %.0f m', g{2});
        case 'exit_line'
            s = sprintf('切出直飞 %.0f m', g{2});
        case 'line_to'
            s = sprintf('飞往 (%.0f, %.0f)', g{2}(1), g{2}(2));
        case 'goto'
            h = g{2}(3);
            if isnan(h)
                s = sprintf('飞往 (%.0f, %.0f)（到达航向不限）', g{2}(1), g{2}(2));
            else
                s = sprintf('飞往 (%.0f, %.0f)，到达航向 %.0f°', g{2}(1), g{2}(2), h);
            end
        case 'orbit'
            s = sprintf('绕 (%.0f, %.0f) 半径 %.0f m %s %d 圈', ...
                g{2}(1), g{2}(2), g{3}, tern(g{4}), g{5});
        otherwise
            s = g{1};
    end
end

function s = tern(dir)
    if strcmp(dir, 'CW'), s = '顺时针'; else, s = '逆时针'; end
end
