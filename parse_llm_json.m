function raw = parse_llm_json(txt)
% PARSE_LLM_JSON 解析 LLM 回复中的 JSON 文本（纯函数，供离线测试）
% 返回：含 segments（或 action）的 struct，或空 []。
% 兼容三种形态：
%   1) {"segments":[...], "assumptions":[...]}        —— 标准输出
%   2) [ {...}, {...} ]                               —— 顶层数组（包成 segments）
%   3) {"plan": {"segments":[...]}} / {"route": ...}  —— 嵌套一层（自动拆开）
    raw = [];
    if ~ischar(txt) && ~isstring(txt), return; end
    try
        v = jsondecode(char(txt));
    catch
        return;
    end

    if iscell(v)                          % 顶层数组
        raw = struct('segments', {v});
        return;
    end
    if ~isstruct(v), return; end

    if isstruct(v) && numel(v) > 1        % 结构数组：取含 segments/action 的项
        has = arrayfun(@(s) isfield(s, 'segments') || isfield(s, 'action'), v);
        if any(has), raw = v(find(has, 1)); return; end
    end
    if isfield(v, 'segments') || isfield(v, 'action')
        raw = v;
        return;
    end
    % 嵌套一层：找唯一含 segments/action 的子结构
    fn = fieldnames(v);
    for k = 1:numel(fn)
        sub = v.(fn{k});
        if isstruct(sub) && (isfield(sub, 'segments') || isfield(sub, 'action'))
            raw = sub;
            if isfield(v, 'assumptions') && ~isfield(raw, 'assumptions')
                raw.assumptions = v.assumptions;
            end
            return;
        end
    end
end
