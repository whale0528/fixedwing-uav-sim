function raw = llm2route(instruction, opts)
% LLM2ROUTE 自然语言 → 无人机路线 JSON（DeepSeek，temperature=0，严格 JSON）
% 只负责"抽取"：把一句话翻成动作单 JSON；合法性由 check_route_spec 校验。
%
% instruction : 用户指令（中文自然语言）
% opts        : 可选
%   Key        API Key（默认读 KeyFile）
%   KeyFile    存放 Key 的文件（默认 llm_key.txt，已 gitignore）
%   BaseUrl    接口地址（默认 https://api.deepseek.com/chat/completions）
%   Model      模型名（默认 deepseek-chat）
%   Retry      重试次数（默认 3）
%   Timeout    超时秒数（默认 60）
%   Landmarks  地标白名单（默认 塔A~塔D + 训练空域中心）
% 返回 raw : struct（含 segments / assumptions），或报错
%
% 输出 JSON 结构（本函数在 system prompt 中约束模型照此输出）：
%   {"segments":[{"type":"orbit","center_ref":"训练空域中心","radius_m":500,
%                 "direction":"CW","turns":2}, ...],
%    "assumptions":["..."]}
    arguments
        instruction (1,:) char
        opts.Key (1,:) char = ''
        opts.KeyFile (1,:) char = 'llm_key.txt'
        opts.BaseUrl (1,:) char = 'https://api.deepseek.com/chat/completions'
        opts.Model (1,:) char = 'deepseek-chat'
        opts.Retry (1,1) double {mustBeInteger, mustBePositive} = 3
        opts.Timeout (1,1) double = 60
        opts.Landmarks (1,:) string = ["塔A", "塔B", "塔C", "塔D", "训练空域中心"]
    end

    if isempty(opts.Key)
        if ~isfile(opts.KeyFile)
            error('llm2route:noKey', '找不到 %s，请把 DeepSeek API Key 写入该文件', opts.KeyFile);
        end
        opts.Key = strtrim(fileread(opts.KeyFile));
    end
    if isempty(opts.Key)
        error('llm2route:noKey', 'API Key 为空');
    end

    lm_list = strjoin(opts.Landmarks, "、");
    sys = [ ...
        '你是无人机任务规划助手。把用户的自然语言指令翻译成"动作单"JSON，只输出 JSON，不要任何解释。' ...
        'JSON 结构固定为：{"segments":[ ... ],"assumptions":["..."]}。' ...
        'segments 是动作数组，每个动作只能是下列之一（字段名必须完全一致）：' ...
        '{"type":"turn_to","heading_deg":<数字>}  转向指定航向；' ...
        '{"type":"line","dist_m":<数字>}  沿当前航向直飞指定距离；' ...
        '{"type":"line_to","target_ref":"<地标名>"}  飞到某地标；' ...
        '{"type":"goto","target_ref":"<地标名>","heading_deg":<数字或 null>}  飞到某地标并指定到达航向；' ...
        '{"type":"orbit","center_ref":"<地标名>","radius_m":<数字>,"direction":"CW或CCW","turns":<整数>}  绕某地标转圈；' ...
        '{"type":"exit_line","dist_m":<数字>}  沿当前航向切出。' ...
        '硬性规则：' ...
        '1) 地标只能使用这些名字：' char(lm_list) '；任何情况下都不要输出坐标数字；' ...
        '2) 不要做任何数值计算或换算，只照抄用户给出的数字；用户没给的参数就省略该字段，并把缺什么写进 assumptions；' ...
        '3) 单位：距离一律米，航向一律度（0=正北，90=正东，180=正南，270=正西）；' ...
        '4) direction 只能是 "CW"（顺时针）或 "CCW"（逆时针）；绕圈半径不得小于 400 米；' ...
        '5) 动作数不超过 12 个；' ...
        '6) 用户若只说"转圈/绕圈"而没说方向，可省略 direction 或写 "CW"；若连圈数也没说，省略 turns。' ...
        '示例：指令"向北飞2000米后绕训练空域中心半径500米顺时针转两圈" → ' ...
        '{"segments":[{"type":"turn_to","heading_deg":0},{"type":"line","dist_m":2000},' ...
        '{"type":"orbit","center_ref":"训练空域中心","radius_m":500,"direction":"CW","turns":2}],"assumptions":[]}'];

    body = struct('model', opts.Model, 'temperature', 0, ...
                  'response_format', struct('type', 'json_object'), ...
                  'messages', {{ ...
                      struct('role', 'system', 'content', sys), ...
                      struct('role', 'user',   'content', ['指令：' instruction]) }});

    wo = weboptions('RequestMethod', 'post', 'MediaType', 'application/json', ...
                    'HeaderFields', {'Authorization', ['Bearer ' opts.Key]}, ...
                    'ContentType', 'json', 'Timeout', opts.Timeout);

    last_err = '';
    for k = 1:opts.Retry
        try
            resp = webwrite(opts.BaseUrl, jsonencode(body), wo);
            if ischar(resp) || isstring(resp), resp = jsondecode(resp); end
            txt = resp.choices(1).message.content;
            raw = parse_llm_json(txt);
            if ~isempty(raw), return; end
            last_err = sprintf('第 %d 次：返回内容不含 segments', k);
        catch ME
            last_err = sprintf('第 %d 次：%s', k, ME.message);
        end
    end
    error('llm2route:failed', '多次尝试后仍未获得合法路线 JSON。%s', last_err);
end
