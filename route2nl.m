function txt = route2nl(plan, opts)
% ROUTE2NL 把校验后的动作单回译成一句自然语言（供人工确认，HITL）
% 失败（无 key/无网络/解析异常）时返回空字符串，调用方回退到确定性清单，不阻塞流程。
% plan : check_route_spec 的输出（plan.segments 坐标已解析）
% 用法：txt = route2nl(plan)
    arguments
        plan (1,1) struct
        opts.Key (1,:) char = ''
        opts.KeyFile (1,:) char = 'llm_key.txt'
        opts.BaseUrl (1,:) char = 'https://api.deepseek.com/chat/completions'
        opts.Model (1,:) char = 'deepseek-chat'
        opts.Timeout (1,1) double = 30
    end
    txt = '';
    try
        if isempty(opts.Key)
            if ~isfile(opts.KeyFile), return; end
            opts.Key = strtrim(fileread(opts.KeyFile));
        end
        if isempty(opts.Key) || contains(opts.Key, '请把这一行'), return; end

        sys = ['你是无人机任务复述员。用户会给你一份"动作单"，你要用一句中文把它复述清楚，' ...
               '让人一看就知道飞机接下来要干什么。只输出这一句话，不要 JSON、不要列表、不要解释。' ...
               '要点：先干什么、再飞多远/飞到哪个地标、在哪个地标上空绕几圈、顺时针还是逆时针、最后做什么。'];
        user = ['动作单：' plan_to_text(plan)];

        body = struct('model', opts.Model, 'temperature', 0, ...
                      'messages', {{ struct('role','system','content',sys), ...
                                     struct('role','user','content',user) }});
        wo = weboptions('RequestMethod', 'post', 'MediaType', 'application/json', ...
                        'HeaderFields', {'Authorization', ['Bearer ' opts.Key]}, ...
                        'ContentType', 'json', 'Timeout', opts.Timeout);
        resp = webwrite(opts.BaseUrl, jsonencode(body), wo);
        if ischar(resp) || isstring(resp), resp = jsondecode(resp); end
        txt = strtrim(char(resp.choices(1).message.content));
    catch
        txt = '';        % 回译失败不阻塞流程
    end
end

function s = plan_to_text(plan)
% 把动作单转成便于 LLM 复述的紧凑文本
    parts = {};
    for k = 1:numel(plan.segments)
        g = plan.segments{k};
        switch g{1}
            case 'turn_to'
                parts{end+1} = sprintf('转向航向 %.0f 度', g{2});            %#ok<AGROW>
            case 'line'
                parts{end+1} = sprintf('沿当前航向直飞 %.0f 米', g{2});       %#ok<AGROW>
            case 'exit_line'
                parts{end+1} = sprintf('切出直飞 %.0f 米', g{2});            %#ok<AGROW>
            case 'line_to'
                parts{end+1} = sprintf('飞往地标点 (%.0f, %.0f)', g{2});      %#ok<AGROW>
            case 'goto'
                h = g{2}(3);
                if isnan(h)
                    parts{end+1} = sprintf('飞往地标点 (%.0f, %.0f)（到达航向不限）', g{2}(1), g{2}(2)); %#ok<AGROW>
                else
                    parts{end+1} = sprintf('飞往地标点 (%.0f, %.0f)，到达航向 %.0f 度', g{2}(1), g{2}(2), h); %#ok<AGROW>
                end
            case 'orbit'
                parts{end+1} = sprintf('在该地标点 (%.0f, %.0f) 上空绕圈：半径 %.0f 米、%s、%d 圈', ...
                    g{2}(1), g{2}(2), g{3}, tern(g{4}, '顺时针', '逆时针'), g{5}); %#ok<AGROW>
        end
    end
    s = strjoin(parts, '；然后 ');
end

function s = tern(dir, a, b)
    if strcmp(dir, 'CW'), s = a; else, s = b; end
end
