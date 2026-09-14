function debug_replay_flyphase()
% DEBUG_REPLAY_FLYPHASE 用实飞轨迹回放 fly_phase 切换逻辑（调试用，不入库）
% 逻辑照搬 b0307.mdl 航路跟踪/MATLAB Function 的 fly_phase + update_segment_data，
% DTG 按制导子系统 dy_dydot_subsystem 的公式复算。
out = evalin('base','out');
t = out.tout;
xn = out.simout.Data(:,1); xe = out.simout.Data(:,2);
% 降采样到 0.1 s（原 0.001 s，60 万~200 万点直接回放太慢）
tq = t(1):0.1:t(end);
xn = interp1(t, xn, tq);
xe = interp1(t, xe, tq);
t = tq;
fly_pt = evalin('base','fly_pt');
n = size(fly_pt,1);
fprintf('fly_pt 共 %d 行:\n', n);
for k = 1:n
    fprintf('  %2d: N=%9.1f E=%9.1f z=%4.0f type=%4.0f info=%7.0f\n', ...
        k, fly_pt(k,1), fly_pt(k,2), fly_pt(k,3), fly_pt(k,4), fly_pt(k,5));
end

% --- 回放（降采样后的步长）---
fp = 1;
[fly_type, prev_pt, next_pt, coc_pt, fp] = update_segment_data(fly_pt, fp);
arc_entered = false;
fprintf('\n航段切换时间线:\n');
for k = 1:numel(t)
    ti = t(k);
    xyz = [xn(k), xe(k), 300];

    if fly_type == 2
        DTG = dtg_circle(next_pt, xyz, coc_pt);
    else
        [~,~,DTG] = line_calculation(prev_pt, next_pt, xyz, [0 0 0]);
    end

    has_crossed = false;
    if ti > 0.1
        if fly_type == 1
            seg_vec = next_pt(1:3) - prev_pt(1:3);
            seg_len = norm(seg_vec);
            if seg_len > 1e-3
                seg_dir = seg_vec / seg_len;
                along = dot(xyz - prev_pt(1:3), seg_dir);
                has_crossed = along >= seg_len;
            else
                has_crossed = true;
            end
            arc_entered = false;
        elseif fly_type == 2
            x0 = coc_pt(1); y0 = coc_pt(2);
            radius = coc_pt(5);
            dir_type = prev_pt(5);
            dist_to_center = norm(xyz(1:2) - [x0, y0]);
            if ~arc_entered
                if abs(dist_to_center - radius) < radius*0.3 || DTG < 50
                    arc_entered = true;
                end
            end
            if arc_entered
                theta_entry = atan2(prev_pt(2)-y0, prev_pt(1)-x0);
                theta_exit  = atan2(next_pt(2)-y0, next_pt(1)-x0);
                theta_curr  = atan2(xyz(2)-y0, xyz(1)-x0);
                if dir_type == 1
                    total_sweep = mod(theta_entry - theta_exit, 2*pi);
                    sweep = mod(theta_entry - theta_curr, 2*pi);
                else
                    total_sweep = mod(theta_exit - theta_entry, 2*pi);
                    sweep = mod(theta_curr - theta_entry, 2*pi);
                end
                has_crossed = sweep >= total_sweep - 0.01;
            end
        end
    end

    if has_crossed
        fp = fp + 1;
        while fp + 1 < size(fly_pt,1)
            dist_to_next = norm(fly_pt(fp,1:2) - fly_pt(fp+1,1:2));
            if dist_to_next < 0.5
                fp = fp + 1;
            else
                break;
            end
        end
        fprintf('t=%7.1f s  切到行 %2d（type=%g）\n', ti, fp, fly_pt(fp,4));
        if fp + 1 <= size(fly_pt,1)
            [fly_type, prev_pt, next_pt, coc_pt, fp] = update_segment_data(fly_pt, fp);
            arc_entered = false;
        end
    end
end
fprintf('回放结束: 最终 fp=%d (共 %d 行), 末段 type=%g\n', fp, n, fly_type);
end

% ---- 照搬 fly_phase 的 update_segment_data ----
function [type, p_pt, n_pt, c_pt, new_idx] = update_segment_data(fly_pt, idx)
    new_idx = idx;
    p_pt = fly_pt(new_idx, :);
    type = p_pt(4);
    n_pt = fly_pt(new_idx + 1, :);
    c_pt = [0 0 0 1 0];
    if type == 2
        cand_n_pt = fly_pt(new_idx + 1, :);
        if cand_n_pt(4) == 2 && cand_n_pt(5) ~= 1 && cand_n_pt(5) ~= 2
            c_pt = cand_n_pt;
            if new_idx + 2 <= size(fly_pt, 1)
                new_idx = new_idx + 1;
                n_pt = fly_pt(new_idx + 1, :);
            end
        end
    end
end

% ---- 照搬制导的 DTG 计算 ----
function DTG = dtg_circle(next_pt, current_pt, coc_pt)
    x_cur = current_pt(1); y_cur = current_pt(2);
    x_next = next_pt(1); y_next = next_pt(2);
    x0 = coc_pt(1); y0 = coc_pt(2);
    radius = coc_pt(5);
    O_cur = [x_cur - x0, y_cur - y0];
    O_nex = [x_next - x0, y_next - y0];
    cos_angle = dot(O_cur, O_nex) / (norm(O_cur) * norm(O_nex) + eps);
    cos_angle = min(max(cos_angle, -1), 1);
    DTG = radius * acos(cos_angle);
end

function [dy_line, dy_dot_line, DTG_line] = line_calculation(prev_pt, next_pt, current_pt, Vxyz_g)
    x1 = prev_pt(1); y1 = prev_pt(2);
    x2 = next_pt(1); y2 = next_pt(2);
    x  = current_pt(1); y = current_pt(2);
    vx = Vxyz_g(1); vy = Vxyz_g(2);
    dx = x2 - x1; dy = y2 - y1;
    if dx > 0
        true_psi = atan2(dy, dx);
    elseif dx < 0
        true_psi = pi - atan2(dy, abs(dx));
    else
        if dy > 0, true_psi = pi/2;
        elseif dy < 0, true_psi = 3*pi/2;
        else, true_psi = 0; end
    end
    c = cos(true_psi); s = sin(true_psi);
    T = [c, -s; s, c];
    V_prev_next = T * [y2 - y1; x2 - x1];
    V_prev_curr = T * [y - y1; x - x1];
    dy_line = V_prev_curr(1);
    norm_next = norm(V_prev_next);
    if norm_next > 1e-10
        L_temp = dot(V_prev_next, V_prev_curr) / norm_next;
        DTG_line = norm_next - L_temp;
    else
        DTG_line = 0;
    end
    dy_dot_line = -vx * s + vy * c;
end
