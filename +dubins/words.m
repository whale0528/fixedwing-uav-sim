function [ok, t, p, q] = words(alpha, beta, d, type)
% DUBINS.WORDS LSL/RSR/LSR/RSL 四种 word 的弧长参数求解
% 提取自 dubins_path_planning.m 的局部函数 dubins_words，逻辑未改动
    ok = false; t=0; p=0; q=0; ca=cos(alpha); sa=sin(alpha); cb=cos(beta); sb=sin(beta); cab=cos(alpha-beta);
    switch type
        case 'LSL', p2=2+d^2-2*cab+2*d*(sa-sb); if p2>=0, p=sqrt(p2); t=mod(-alpha+atan2(cb-ca,d+sa-sb),2*pi); q=mod(beta-atan2(cb-ca,d+sa-sb),2*pi); ok=true; end
        case 'RSR', p2=2+d^2-2*cab+2*d*(sb-sa); if p2>=0, p=sqrt(p2); t=mod(alpha-atan2(ca-cb,d-sa+sb),2*pi); q=mod(-beta+atan2(ca-cb,d-sa+sb),2*pi); ok=true; end
        case 'LSR', p2=-2+d^2+2*cab+2*d*(sa+sb); if p2>=0, p=sqrt(p2); t=mod(-alpha+atan2(-ca-cb,d+sa+sb)-atan2(-2,p),2*pi); q=mod(-beta+atan2(-ca-cb,d+sa+sb)-atan2(-2,p),2*pi); ok=true; end
        case 'RSL', p2=-2+d^2+2*cab-2*d*(sa+sb); if p2>=0, p=sqrt(p2); t=mod(alpha-atan2(ca+cb,d-sa-sb)+atan2(2,p),2*pi); q=mod(beta-atan2(ca+cb,d-sa-sb)+atan2(2,p),2*pi); ok=true; end
    end
end
