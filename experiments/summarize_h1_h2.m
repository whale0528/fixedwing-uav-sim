% SUMMARIZE_H1_H2 H1/H2 批量实验结果汇总（混淆矩阵 + 失效模式分类）
% 用法：run('experiments/summarize_h1_h2.m')
% 输入：experiments/results_h1_h2.mat
% 输出：控制台报告 + experiments/H1_H2_results.md

cd(fileparts(mfilename('fullpath')));
cd('..');
addpath(pwd);

S = load(fullfile('experiments', 'results_h1_h2.mat'));
res = S.results;
n = numel(res);

cat = [res.category];
vs_ok = [res.vs_ok];
c_ok = [res.contract_ok];
groups = string({res.group});

fprintf('=== H1/H2 实验结果（b0307 盘旋机动，%d 条样本）===\n\n', n);

% ---- 总体判定 ----
fprintf('【分层判定】\n');
fprintf('  逐参数层（V_S 级）放行 : %d/%d (%.1f%%)\n', sum(vs_ok), n, 100*sum(vs_ok)/n);
fprintf('  契约层判定可行         : %d/%d (%.1f%%)\n\n', sum(c_ok), n, 100*sum(c_ok)/n);

% ---- 四类失效模式 ----
fprintf('【四类失效模式】\n');
names = {'类别1 逐参数层拒绝（范围/类型）', ...
         '类别2 放行但违反失速（单参数物理）', ...
         '类别3 ★放行但跨参数不可行', ...
         '类别4 两层都放行（可行）'};
for c = 1:4
    fprintf('  %-34s : %2d 条 (%.1f%%)\n', names{c}, sum(cat == c), 100*sum(cat == c)/n);
end

% ---- H2 核心：漏报率 ----
n_vs_pass = sum(vs_ok);
n_vs_miss = sum(vs_ok & ~c_ok);
fprintf('\n【H2 核心指标：逐参数层对"物理不可行"的漏报】\n');
fprintf('  放行样本中被契约层判为不可行 : %d / %d = **%.1f%%**\n', ...
        n_vs_miss, n_vs_pass, 100*n_vs_miss/max(n_vs_pass, 1));

% ---- H1 核心：跨参数不可行（细分为显式/含默认值）----
idx3 = find(cat == 3);
n3_expl = 0; n3_def = 0;
for k = idx3
    mi = res(k).intended;
    explicit = ~isnan(mi(1)) && ~isnan(mi(2));      % r 与 v 都由用户明确给出
    if explicit, n3_expl = n3_expl + 1; else, n3_def = n3_def + 1; end
end
fprintf('\n【H1 核心指标：跨参数不可行（类别3）】\n');
fprintf('  合计 %d 条 (%.1f%%)，其中：\n', numel(idx3), 100*numel(idx3)/n);
fprintf('    3a 用户显式给出的组合本身不可行 : %d 条\n', n3_expl);
fprintf('    3b 缺参默认值注入后与显式参数冲突 : %d 条 ← 一类独立失效模式\n', n3_def);

% ---- 违反约束分布 ----
fprintf('\n【违反约束分布（类别2+3）】\n');
allv = strings(0);
for k = find(~c_ok)
    if strlength(res(k).violated) > 0
        allv = [allv, split(res(k).violated, "+")'];   %#ok<AGROW>
    end
end
for cid = ["C1", "C3", "C4", "C5", "C6", "C0"]
    cnt = sum(allv == cid);
    if cnt > 0
        lbl = struct('C1','失速下界','C3','配平/坡度','C4','过载','C5','制导可跟踪','C6','续航','C0','参数缺失').(cid);
        fprintf('  %s %-12s : %d 次\n', cid, lbl, cnt);
    end
end

% ---- 分组对比 ----
fprintf('\n【分组对比】\n');
for g = ["A自然", "B探针"]
    m = groups == g;
    if any(m)
        fprintf('  %s（%d 条）：类别3 = %d 条 (%.1f%%)，可行 = %d 条\n', ...
            g, sum(m), sum(cat(m) == 3), 100*sum(cat(m) == 3)/sum(m), sum(cat(m) == 4));
    end
end

% ---- 典型样本 ----
fprintf('\n【典型样本（类别3，前 8 条）】\n');
for k = idx3(1:min(8, numel(idx3)))
    fprintf('  · %-38s r=%.0f v=%.0f N=%g → 违反 %s\n', ...
        res(k).instruction, res(k).r, res(k).v, res(k).N, res(k).violated);
end

% ---- 写入 markdown ----
fid = fopen(fullfile('experiments', 'H1_H2_results.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# H1/H2 实验结果（自动生成）\n\n');
fprintf(fid, '样本 %d 条（自然说法 %d + 边界探针 %d），机型 b0307（m=27.1kg, S=0.7m², φ_max=30°, V_stall=25.8 m/s）\n\n', ...
    n, sum(groups=="A自然"), sum(groups=="B探针"));
fprintf(fid, '| 指标 | 数值 |\n|---|---|\n');
fprintf(fid, '| 逐参数层（V_S 级）放行率 | %d/%d = %.1f%% |\n', sum(vs_ok), n, 100*sum(vs_ok)/n);
fprintf(fid, '| 契约层判定可行率 | %d/%d = %.1f%% |\n', sum(c_ok), n, 100*sum(c_ok)/n);
fprintf(fid, '| **漏报：放行但物理不可行** | **%d/%d = %.1f%%** |\n', n_vs_miss, n_vs_pass, 100*n_vs_miss/max(n_vs_pass,1));
fprintf(fid, '| 其中跨参数不可行（类别3） | %d 条 (%.1f%%) |\n', numel(idx3), 100*numel(idx3)/n);
fprintf(fid, '| └ 用户显式组合不可行 (3a) | %d 条 |\n', n3_expl);
fprintf(fid, '| └ 默认值注入后冲突 (3b) | %d 条 |\n', n3_def);
fprintf(fid, '| 违反失速（类别2） | %d 条 |\n', sum(cat == 2));
fprintf(fid, '| 逐参数层直接拒绝（类别1） | %d 条 |\n', sum(cat == 1));
fclose(fid);
fprintf('\n已写出 experiments/H1_H2_results.md\n');
