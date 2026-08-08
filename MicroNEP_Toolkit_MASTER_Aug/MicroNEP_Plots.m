%% =========================================================================
%% MicroNEP_Plots.m — Propulsion and Mission Figures
%% =========================================================================
% Generates propulsion, mission, system, and family-comparison figures.
% Thermal figures are in MicroNEP_Thermal_Plots.m.
% Requires MicroNEP_Model.m to have been run first.
% Family figures (19-27) require NEP_RP, NEP_W, NEP_SM; Fig 22 also needs ep.
% Figs 25/26 require rtg_plus from MicroNEP_Params.m.
%
% Tier 1 - core capability:
%   1     Lifetime dV vs N_pulses x I_bit          (capability map)
%   1b    Dual-ceiling capability map (confirmed I_bit only)
%   2     Requirements map (N_pulses x I_bit breakeven per profile)
%   3     Calendar lifetime vs duty cycle
%   4     Mission profile feasibility (dual-constraint bar)
%   5     dV vs spacecraft mass (with I_bit envelope)
%   5b    Pulse-life dV vs spacecraft mass (option C, banded)
%   6 - 8 Stacking performance grid x 3 (dV / total impulse / duty cycle)
%   8b    Stacking — system specific mass grid
%   9     Mission feasibility map (I_total vs alpha_RTG)
%   10    Mission unlock map
%   11    Stacking scaling curves
%
% Tier 2 - parameter sweeps:
%  12     Frequency sweep (F = I_bit x f invariance)
%  13     E_pulse -> I_bit scaling (alpha sweep)
%  14     Store size scaling (burst, recharge, per-cycle dV)
%  15     Lifetime heatmaps (f x E_store; f x E_pulse)
%
% Tier 3 - system context:
%  16     Recharge time vs RTG power
%  17     RTG power sensitivity
%  18     TEG characterisation
%  19     Isp sensitivity
%  20     Mass budget
%
% Family comparison (require variant scripts):
%  21     Family I_bit and I_total step-up
%  22     Family duty cycle across power options (incl. RTG+ variants)
%  23     Family lifetime dV vs spacecraft mass
%  24     Family feasibility heatmap (requires ep)
%  25     Family total impulse screen (per-mission)
%  26     Warlock system mass vs power-unit count
%  27     Power-scaling: alpha vs P_e (family + benchmark ladder, incl. RTG+)
%  28     Specific mass vs total impulse capability (incl. RTG+ variants)
%  29     Closure-margin heatmap (requires ep)

if ~exist('NEP','var'), error('Run MicroNEP_Model.m first.'); end

rogue      = NEP.params.rogue;    rtg      = NEP.params.rtg;
mppt       = NEP.params.mppt;     cfg      = NEP.params.cfg;
rtg_plus   = NEP.params.rtg_plus;   % PA improved RTG (~40 We, same mass)
teg        = NEP.teg;             cap   = NEP.cap;
mp         = NEP.mp;              bk    = NEP.bkeven;
lfe        = NEP.lfe;             lfep  = NEP.lfep;
req        = NEP.req;             stk   = NEP.stk;
stk_m_sc   = NEP.stk_m_sc;        sg    = NEP.stk_grid;
stk_unlock = NEP.stk_unlock;      sm    = NEP.sm;
cal        = NEP.calendar;
g0         = NEP.const.g0;

% Style helpers.
ax           = @() set(gca,'FontName','Arial','FontSize',13,'LineWidth',1,'Box','on','Layer','top');
fig          = @() set(gcf,'Color','w');
style_legend = @(h) set(h,'Box','on','FontSize',11);
C            = lines(8);

n_stk       = cfg.n_stk_max;
tick_lbl    = string(1:n_stk);
n_prof      = numel(mp);
prof_colors = lines(n_prof);
prof_labels = {mp.label};

spy = 365.25 * 86400;

%% ── FIG 1: Lifetime dV vs N_pulses x I_bit (capability map) ─────────────
figure('Name','dV capability map'); hold on; grid on;
I_bit_labels = arrayfun(@(v) sprintf('%g uN.s', v*1e6), cap.I_bit_lines_Ns, ...
                        'UniformOutput', false);
ls_styles = {'-','--',':','-.'};
ls_cap    = arrayfun(@(k) ls_styles{mod(ceil(k/2)-1, numel(ls_styles))+1}, ...
                     1:numel(cap.I_bit_lines_Ns), 'UniformOutput', false);
for k = 1:numel(cap.I_bit_lines_Ns)
    plot(cap.n_pulses, cap.dV_grid(k,:), ls_cap{k}, ...
         'LineWidth', 1.8, 'Color', C(min(k,8),:), 'DisplayName', I_bit_labels{k});
end
xline(rogue.n_pulses_design,   '--k', '1M',  'LabelOrientation','horizontal','HandleVisibility','off');
xline(rogue.n_pulses_ambition, '--r', '10M', 'LabelOrientation','horizontal','HandleVisibility','off');
set(gca, 'XScale', 'log', 'YScale', 'log');
xlabel('Pulse budget [discharge events]');
ylabel(sprintf('Lifetime \\DeltaV [m/s]'));
title('Lifetime \DeltaV vs pulse budget');
subtitle(sprintf('I_{bit} sensitivity at %.0f kg reference s/c', cap.m_ref_kg));
lgd = legend('Location','northwest'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 1b: Dual-ceiling capability map (confirmed I_bit only) ──────────
% Trimmed single-curve version of Fig 1 for Chapter 5 (sec 5.1.2): shows the
% confirmed 12 uN.s pulse-life ceiling alone, against the duty-cycle ceiling,
% to make the binding-constraint argument without the I_bit family clutter.
% Reuses cap.* (Model.m) and pt.* baseline operating point. The full I_bit
% family (Fig 1) is reused later in the chapter for the lever discussion.
I_bit_conf_Ns = rogue.I_bit_Ns;                         % 12 uN.s confirmed
[~, k_conf]   = min(abs(cap.I_bit_lines_Ns - I_bit_conf_Ns));
dV_conf       = cap.dV_grid(k_conf, :);                 % pulse-life curve, m/s

% Duty-cycle ceiling as a horizontal reference (per-year rate, m/s/yr).
% Independent of pulse budget -> flat line across the N_pulses axis.
dV_duty_ref = NEP.dV_duty_ceiling;                      % 17.0 m/s/yr at design
if isempty(dV_duty_ref) || ~isfinite(dV_duty_ref)
    dV_duty_ref = 17.01;                                % hardcoded fallback
end

figure('Name','Dual-ceiling capability map'); hold on; grid on;
plot(cap.n_pulses, dV_conf, '-', 'LineWidth', 2.2, 'Color', C(2,:), ...
     'DisplayName', sprintf('Pulse-life ceiling (%g uN.s)', I_bit_conf_Ns*1e6));
yline(dV_duty_ref, '--', sprintf('Duty ceiling %.1f m/s/yr', dV_duty_ref), ...
      'Color', C(1,:), 'LineWidth', 1.8, 'LabelHorizontalAlignment','left', ...
      'HandleVisibility','off');
xline(rogue.n_pulses_design,   '--k', '1M baseline', ...
      'LabelOrientation','horizontal','HandleVisibility','off');
xline(rogue.n_pulses_ambition, '--r', '10M stretch', ...
      'LabelOrientation','horizontal','HandleVisibility','off');
set(gca, 'XScale', 'log', 'YScale', 'log');
xlabel('Pulse budget [discharge events]');
ylabel('\DeltaV [m/s  (pulse-life)  |  m/s/yr  (duty)]');
title('Dual-ceiling capability map');
subtitle(sprintf('Confirmed I_{bit} = %g uN.s at %.0f kg reference s/c', ...
                 I_bit_conf_Ns*1e6, cap.m_ref_kg));
lgd = legend('Location','northwest'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 2: Requirements map (N_pulses x I_bit breakeven) ────────────────
figure('Name', 'Requirements map'); hold on; grid on;
x_lim = [5 10000];
tier_colors_lt = {[0.85 0.97 0.87], [1.0 0.95 0.82], [1.0 0.87 0.87]};
tier_N_bounds  = cfg.req_tiers_Ns ./ rogue.I_bit_Ns;
N_lo = cfg.N_pulses_sweep(1);
for t = 1:3
    N_hi = tier_N_bounds(t);
    if t > 1, N_lo = tier_N_bounds(t-1); end
    if N_hi > N_lo
        patch([x_lim(1) x_lim(2) x_lim(2) x_lim(1)], [N_lo N_lo N_hi N_hi], ...
            tier_colors_lt{t}, 'EdgeColor','none','FaceAlpha',0.55,'HandleVisibility','off');
        text(x_lim(2)*0.65, N_hi * 0.5, cfg.req_tier_labels{t}, ...
            'FontSize', 10, 'Color', [0.25 0.25 0.25], 'FontWeight', 'bold', ...
            'HorizontalAlignment','right','VerticalAlignment','top');
    end
end
for i = 1:n_prof
    plot(bk.I_bit_sweep_Ns*1e6, bk.N_req(i,:), '-', ...
        'LineWidth', 1.8, 'Color', prof_colors(i,:), 'DisplayName', mp(i).label);
end
plot(rogue.I_bit_Ns*1e6, rogue.n_pulses_ambition, 'kx', 'MarkerSize', 14, ...
    'LineWidth', 2.5, 'HandleVisibility','off');
text(rogue.I_bit_Ns*1e6*1.15, rogue.n_pulses_ambition, 'Rogue demo', ...
    'FontSize', 10, 'FontWeight','bold', 'Color',[0 0 0], ...
    'VerticalAlignment','middle','Interpreter','none');
% Additional family operating points: (I_bit, N_max = I_total_spec / I_bit)
fam2_mrk = {'bs','r^','md'};  fam2_ms = [9, 9, 9];
fam2_short = {'Rogue public','Warlock','SuperMag'};
fam2_clr   = {[0.10 0.35 0.75],[0.80 0.15 0.15],[0.65 0.20 0.70]};
fam2_va    = {'bottom','bottom','top'};   % stagger to avoid marker overlap
fam2_structs = {};
if exist('NEP_RP','var'), fam2_structs{end+1} = NEP_RP; end
if exist('NEP_W', 'var'), fam2_structs{end+1} = NEP_W;  end
if exist('NEP_SM','var'), fam2_structs{end+1} = NEP_SM; end
for fi2 = 1:numel(fam2_structs)
    fs = fam2_structs{fi2};
    N_max = fs.I_total_Ns / fs.I_bit_Ns;
    plot(fs.I_bit_Ns*1e6, N_max, fam2_mrk{fi2}, 'MarkerSize', fam2_ms(fi2), ...
        'LineWidth', 2, 'HandleVisibility','off');
    text(fs.I_bit_Ns*1e6*1.15, N_max, fam2_short{fi2}, ...
        'FontSize', 10, 'FontWeight','bold', 'Color', fam2_clr{fi2}, ...
        'VerticalAlignment', fam2_va{fi2}, 'Interpreter','none');
end
yline(rogue.n_pulses_design,   ':k',  '1M',  'LabelOrientation','horizontal','HandleVisibility','off');
yline(rogue.n_pulses_ambition, '--r', '10M', 'LabelOrientation','horizontal','HandleVisibility','off');
yline(100e6,                   ':b',  '100M','LabelOrientation','horizontal','HandleVisibility','off');
set(gca,'XScale','log','YScale','log','XLim', x_lim);
xlabel('I_{bit} [uN.s]');
ylabel('Pulse budget required');
title('Mission requirements map - impulse bit vs pulse budget');
lgd = legend('Location','southwest'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 3: Calendar lifetime vs duty cycle ──────────────────────────────
figure('Name','Calendar lifetime'); hold on; grid on;
duty_smooth = logspace(-4, 0, 300);
life_smooth = (cal.t_fire_total_s ./ duty_smooth) / (86400*365.25);
plot(duty_smooth*100, life_smooth, '-', 'LineWidth', 2, 'Color', C(1,:), ...
    'DisplayName', sprintf('%.0fM pulses @ %.0f Hz', cal.N_pulses/1e6, cal.f_Hz));
scatter(cal.duty_pct, cal.life_years, 50, C(2,:), 'filled', 'DisplayName', 'Model duty cases');
scatter(cal.model_duty_pct, cal.model_life_days/365.25, 80, 'r', 'filled', ...
    'DisplayName', sprintf('Hardware max %.2f%%', cal.model_duty_pct));
text(cal.model_duty_pct*1.15, cal.model_life_days/365.25, ...
    sprintf(' %.0f days', cal.model_life_days), 'Color', 'r', 'FontSize', 9);
xline(3,   '--', 'Color',[0.5 0.5 0.5], 'HandleVisibility','off');
xline(0.5, '--', 'Color',[0.5 0.5 0.5], 'HandleVisibility','off');
xline(0.1, '--', 'Color',[0.5 0.5 0.5], 'HandleVisibility','off');
text(3.3,  0.03, 'LEO ops',    'FontSize', 9, 'Color', [0.4 0.4 0.4], 'Rotation', 90);
text(0.55, 0.03, 'Cislunar',   'FontSize', 9, 'Color', [0.4 0.4 0.4], 'Rotation', 90);
text(0.11, 0.03, 'Deep-space', 'FontSize', 9, 'Color', [0.4 0.4 0.4], 'Rotation', 90);
set(gca,'XScale','log','YScale','log');
xlim([0.01 100]); ylim([0.05 5000]);
xlabel('Duty cycle [%]');
ylabel('Calendar lifetime [years]');
title('Calendar lifetime vs duty cycle');
subtitle(sprintf('%.0fM pulses, %.1f h total firing time', cal.N_pulses/1e6, cal.t_fire_total_s/3600));
lgd = legend('Location','southwest'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 4: Mission profile feasibility — Magdrive family (4×1 shared-axis) ─
figure('Name','Mission feasibility');
set(gcf, 'Position', [100 30 900 1000]);
tl = tiledlayout(4, 1, 'TileSpacing','compact', 'Padding','compact');
SPY_f4 = 365.25 * 24 * 3600;
fam4_lbl  = {'Rogue Demo (RTG)',  'Rogue Public (RTG)', 'Warlock (RTG+)',  'SuperMagdrive (RSG-200)'};
fam4_data = { ...
    rogue.I_bit_Ns,  rogue.I_bit_Ns*rogue.n_pulses_ambition, ...
    rogue.I_bit_Ns*rogue.f_Hz*1e3, NEP.rc_max.duty_cycle, rogue.Isp_s; ...
    NaN, NaN, NaN, NaN, NaN; ...
    NaN, NaN, NaN, NaN, NaN; ...
    NaN, NaN, NaN, NaN, NaN };
if exist('NEP_RP','var'), fam4_data(2,:) = {NEP_RP.I_bit_Ns, NEP_RP.I_total_Ns, NEP_RP.F_max_mN, NEP_RP.ops.duty_pct/100, NEP_RP.Isp_s}; end
if exist('NEP_W', 'var'), fam4_data(3,:) = {NEP_W.I_bit_Ns,  NEP_W.I_total_Ns,  NEP_W.F_max_mN,  NEP_W.ops.duty_pct/100,  NEP_W.Isp_s};  end
if exist('NEP_SM','var'), fam4_data(4,:) = {NEP_SM.I_bit_Ns, NEP_SM.I_total_Ns, NEP_SM.F_max_mN, NEP_SM.ops.duty_pct/100, NEP_SM.Isp_s}; end
x_f4 = 1:n_prof;  bw = 0.25;
dV_req_vals = [mp.dV_req_ms];
yt_cands = [0.01 0.1 1 10 100 1000 10000 100000];
ax_f4 = gobjects(4,1);
for fi = 1:4
    Ib = fam4_data{fi,1};
    if isnan(Ib), continue; end
    It = fam4_data{fi,2};  Fn = fam4_data{fi,3};
    dt = fam4_data{fi,4};  Is = fam4_data{fi,5};
    dV_duty = zeros(1,n_prof);  dV_10M = zeros(1,n_prof);  dV_1M = zeros(1,n_prof);
    for k = 1:n_prof
        m          = mp(k).m_sc_kg;
        dV_duty(k) = Fn * 1e-3 * dt * SPY_f4 / m;
        I_d10      = min(Ib * 10e6, It);
        I_d1       = min(Ib *  1e6, It);
        dV_10M(k)  = Is * g0 * log(m / max(m - I_d10/(Is*g0), m*0.001));
        dV_1M(k)   = Is * g0 * log(m / max(m - I_d1 /(Is*g0), m*0.001));
    end
    dV_10M(isnan(dV_10M)) = 1e-3;  dV_1M(isnan(dV_1M)) = 1e-3;
    ax_f4(fi) = nexttile(tl); hold on; grid on;
    bar(x_f4-bw, dV_duty, bw, 'FaceColor',[0.4 0.6 0.9], 'DisplayName','Duty ceiling [m/s/yr]');
    bar(x_f4,    dV_10M,  bw, 'FaceColor',[0.9 0.5 0.3], 'DisplayName','Pulse-life @ 10M [m/s]');
    bar(x_f4+bw, dV_1M,   bw, 'FaceColor',[0.85 0.85 0.3],'DisplayName','Pulse-life @ 1M [m/s]');
    plot(x_f4, dV_req_vals, 'kd','MarkerSize',6,'MarkerFaceColor','k','DisplayName','Requirement');
    set(gca,'XTick',x_f4,'YScale','log','TickLabelInterpreter','none');
    if fi < 4
        set(gca,'XTickLabel',{});
    else
        set(gca,'XTickLabel',prof_labels,'XTickLabelRotation',35);

    end
    y_top = max([dV_req_vals, dV_duty, dV_10M]) * 3;
    ylim([max(0.05, min([dV_req_vals, dV_duty, dV_10M])*0.3), y_top]);
    % Plain decimal y-tick labels, set after ylim and ax()
    title(fam4_lbl{fi}, 'FontWeight','bold', 'FontSize', 9);
    ylabel('\DeltaV [m/s]', 'FontSize', 8);
    if fi == 1, lgd = legend('Location','northeast'); style_legend(lgd); end
    ax(); hold off;
    % Must come after ax() to survive any tick reset it applies
    yl = ylim;
    yt = yt_cands(yt_cands >= yl(1)*0.99 & yt_cands <= yl(2)*1.01);
    if numel(yt) >= 2
        yticks(yt);
        yticklabels(arrayfun(@(v) sprintf('%g', v), yt, 'UniformOutput', false));
    end
end
linkaxes(ax_f4(isgraphics(ax_f4,'axes')), 'x');
title(tl, 'Mission profile feasibility — Magdrive family  [default power per variant]', ...
    'FontSize', 11, 'FontWeight', 'bold');
fig();

%% ── FIG 5: dV vs spacecraft mass (I_bit envelope) ───────────────────────
figure('Name','dV vs spacecraft mass'); hold on; grid on;
m_vals     = [NEP.dv_sc.m_sc_kg];
dV_duty_sc = [NEP.dv_sc.dV_duty_ms];
dV_lo_sc   = [NEP.dv_sc.dV_duty_lo_ms];
dV_hi_sc   = [NEP.dv_sc.dV_duty_hi_ms];
dV_10M_sc  = [NEP.dv_sc.dV_life_10M_total_ms];
dV_1M_sc   = [NEP.dv_sc.dV_life_1M_total_ms];
fill([m_vals, fliplr(m_vals)], [dV_lo_sc, fliplr(dV_hi_sc)], C(1,:), ...
    'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility','off');
plot(m_vals, dV_duty_sc, '-o', 'LineWidth', 2, 'Color', C(1,:), 'MarkerFaceColor', C(1,:), ...
    'DisplayName', 'Duty ceiling (m/s/yr)');
plot(m_vals, dV_10M_sc, '-s', 'LineWidth', 2, 'Color', C(2,:), 'MarkerFaceColor', C(2,:), ...
    'DisplayName', 'Pulse-life @ 10M (m/s)');
plot(m_vals, dV_1M_sc,  '-^', 'LineWidth', 1.5, 'Color', C(3,:), 'MarkerFaceColor', C(3,:), ...
    'DisplayName', 'Pulse-life @ 1M (m/s)');
xline(cfg.m_prop_sys_kg,'--k',sprintf('System %.1f kg',cfg.m_prop_sys_kg), ...
    'HandleVisibility','off','LabelOrientation','horizontal');
xlabel('Spacecraft wet mass [kg]');
ylabel('\DeltaV [m/s]');
title('\DeltaV vs spacecraft mass');
subtitle('Shaded band = I_{bit} uncertainty (10-20 uN.s)');
lgd = legend('Location','northeast'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 5b: Pulse-life dV vs spacecraft mass (option C, banded) ─────────
% Clean pulse-life-only companion to Fig 5. The duty ceiling (m/s/yr) is
% dropped: this figure's job is the 1/m_sc scaling of *deliverable* dV, which
% is a pure pulse-life story. Log-y renders the 1M and 10M curves as parallel
% lines and keeps the low-end (1M) curve legible. I_bit uncertainty band
% (10-20 uN.s) is applied to BOTH pulse-life curves (omitted in Fig 5).
m_vals = [NEP.dv_sc.m_sc_kg];
g0_loc = 9.80665;

% Recompute pulse-life dV at min/max I_bit for the uncertainty bands.
% Inlined exact Tsiolkovsky (delta_v_lifetime is local to Model.m, not in scope here):
%   m_prop = I_bit * N / (Isp*g0);  dV = Isp*g0*ln( m_sc / (m_sc - m_prop) )
% NaN where the closing mass is infeasible (m_prop >= m_sc - m_sys).
m_vals = [NEP.dv_sc.m_sc_kg];
g0_loc = 9.80665;
m_sys  = cfg.m_prop_sys_kg;
Isp    = rogue.Isp_s;

dvlife = @(Ibit, N, m) local_tsiol(Ibit, N, m, m_sys, Isp, g0_loc);

nB = numel(m_vals);
[dV1M_lo, dV1M_hi, dV10M_lo, dV10M_hi] = deal(nan(1,nB));
for i = 1:nB
    m = m_vals(i);
    dV1M_lo(i)  = dvlife(rogue.I_bit_min_Ns, rogue.n_pulses_design,   m);
    dV1M_hi(i)  = dvlife(rogue.I_bit_max_Ns, rogue.n_pulses_design,   m);
    dV10M_lo(i) = dvlife(rogue.I_bit_min_Ns, rogue.n_pulses_ambition, m);
    dV10M_hi(i) = dvlife(rogue.I_bit_max_Ns, rogue.n_pulses_ambition, m);
end
dV_1M_nom  = [NEP.dv_sc.dV_life_1M_total_ms];
dV_10M_nom = [NEP.dv_sc.dV_life_10M_total_ms];

figure('Name','Pulse-life dV vs spacecraft mass'); hold on; grid on;
fill([m_vals, fliplr(m_vals)], [dV10M_lo, fliplr(dV10M_hi)], C(2,:), ...
     'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility','off');
fill([m_vals, fliplr(m_vals)], [dV1M_lo,  fliplr(dV1M_hi)],  C(3,:), ...
     'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility','off');
plot(m_vals, dV_10M_nom, '-s', 'LineWidth', 2, 'Color', C(2,:), 'MarkerFaceColor', C(2,:), ...
     'DisplayName', 'Pulse-life @ 10M (stretch)');
plot(m_vals, dV_1M_nom,  '-^', 'LineWidth', 2, 'Color', C(3,:), 'MarkerFaceColor', C(3,:), ...
     'DisplayName', 'Pulse-life @ 1M (baseline)');
xline(cfg.m_prop_sys_kg, '--k', sprintf('System %.1f kg', cfg.m_prop_sys_kg), ...
      'HandleVisibility','off','LabelOrientation','horizontal');
set(gca, 'YScale', 'log');
ylim([0.01 10]);
yticks([0.01 0.1 1 10]);
yticklabels({'0.01','0.1','1','10'});
xlabel('Spacecraft wet mass [kg]');
ylabel('Lifetime \DeltaV [m/s]');
title('Pulse-life \DeltaV vs spacecraft mass');
subtitle('Shaded bands = I_{bit} uncertainty (10-20 uN.s); duty ceiling omitted');
lgd = legend('Location','northeast'); style_legend(lgd); ax(); fig(); hold off;

% Console check: 1/m_sc scaling -> dV(25kg) ~ 2x dV(50kg) at 1M.
[~, i25] = min(abs(m_vals-25)); [~, i50] = min(abs(m_vals-50));
if isfinite(dV_1M_nom(i25)) && isfinite(dV_1M_nom(i50)) && dV_1M_nom(i50) > 0
    r = dV_1M_nom(i25) / dV_1M_nom(i50);
    fprintf('  Fig 5b  pulse-life dV(25kg)/dV(50kg) @1M = %.2f  [%s]\n', ...
            r, ternary(abs(r-2) < 0.15, 'PASS ~2x', 'CHECK'));
end

%% ── FIG 6: Family stacking comparison (2×2 dV grid) ──────────────────────
% Each subplot: n_Rogue × n_RTG heatmap of lifetime dV for one family member.
% I_delivered = min(n_R × I_bit × 10M, n_R × I_total_spec); dV from Tsiolkovsky.
% System mass = n_R × m_thruster + n_T × m_RTG; reference s/c = stk_m_sc(1).
m_ref_stk = stk_m_sc(1);
N_ref_stk = rogue.n_pulses_design;   % 1M pulse budget

% Family parameters [I_bit_Ns, I_total_spec_Ns, m_thruster_kg, label]
fam_stk = { ...
    rogue.I_bit_Ns,     rogue.I_bit_Ns*N_ref_stk,   rogue.mass_kg,  'Rogue (demo)'; ...
    NEP_RP.I_bit_Ns,    NEP_RP.I_total_Ns,           rogue.mass_kg,  'Rogue (public)'; ...
    NEP_W.I_bit_Ns,     NEP_W.I_total_Ns,            NEP_W.m_thruster_kg,  'Warlock'; ...
    NEP_SM.I_bit_Ns,    NEP_SM.I_total_Ns,           NEP_SM.m_thruster_kg, 'SuperMagdrive' };

figure('Name','Family stacking comparison');
for fi = 1:4
    I_bit_f   = fam_stk{fi,1};
    I_spec_f  = fam_stk{fi,2};
    m_thr_f   = fam_stk{fi,3};
    dV_grid_f = zeros(n_stk, n_stk);
    for nr = 1:n_stk
        for nt = 1:n_stk
            I_del  = min(nr * I_bit_f * N_ref_stk, nr * I_spec_f);
            m_sys  = nr * m_thr_f + nt * rtg.mass_kg;
            if m_ref_stk <= m_sys, dV_grid_f(nr,nt) = 0; continue; end
            m_prop = I_del / (rogue.Isp_s * g0);
            if m_prop >= m_ref_stk - m_sys
                dV_grid_f(nr,nt) = rogue.Isp_s * g0 * log(m_ref_stk / (m_sys));
            else
                dV_grid_f(nr,nt) = rogue.Isp_s * g0 * log(m_ref_stk / (m_ref_stk - m_prop));
            end
        end
    end
    subplot(2,2,fi);
    imagesc(dV_grid_f); colormap(gca, parula);
    cb = colorbar; cb.Label.String = 'dV [m/s]';
    hold on;
    for nr = 1:n_stk
        for nt = 1:n_stk
            v = dV_grid_f(nr,nt);
            clr = text_colour_for_value(v, dV_grid_f, false);
            if v >= 0.005
                text(nt, nr, sprintf('%.2f', v), 'HorizontalAlignment','center', ...
                    'VerticalAlignment','middle','FontSize',9,'FontWeight','bold','Color',clr);
            end
        end
    end
    set(gca,'XTick',1:n_stk,'XTickLabel',tick_lbl,'YTick',1:n_stk,'YTickLabel',tick_lbl, ...
            'YDir','normal','FontSize',7);
    xlabel('n_{RTG}'); ylabel('n_{Rogue}');
    title(sprintf('%s  [m/s @ %.0f kg, 10M]', fam_stk{fi,4}, m_ref_stk)); ax();
end
sgtitle(sprintf('Lifetime \DeltaV — stacking grid (%.0f kg s/c, 10M pulses, RTG baseline)', m_ref_stk), ...
        'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'tex');
fig();

%% ── FIG 7: Family stacking — total impulse (2×2 grid) ──────────────────
% I_del(n_R,n_T) = n_R × I_total_spec [kNs].  n_T does not affect total impulse
% but is shown for grid consistency; the duty-cycle figure (Fig 8) shows how
% n_T matters operationally.
fam_stk_I = fam_stk;   % reuse the cell array from Fig 6

figure('Name','Family stacking: total impulse');
for fi = 1:4
    I_spec_f = fam_stk_I{fi,2};   % I_total_spec for this variant
    I_grid   = zeros(n_stk, n_stk);
    for nr = 1:n_stk
        for nt = 1:n_stk
            I_grid(nr,nt) = nr * I_spec_f;   % kNs: divide later for label
        end
    end
    I_kNs = I_grid / 1e3;

    subplot(2,2,fi);
    imagesc(I_kNs); colormap(gca, parula);
    cb = colorbar; cb.Label.String = 'I_{total} [kNs]';
    hold on;
    for nr = 1:n_stk
        for nt = 1:n_stk
            v = I_kNs(nr,nt);
            clr = text_colour_for_value(v, I_kNs, false);  % true = light scale
            if v >= 0.001
                if v >= 1000
                    lbl = sprintf('%.0fk', v/1e3);
                elseif v >= 1
                    lbl = sprintf('%.0f', v);
                else
                    lbl = sprintf('%.2f', v);
                end
                text(nt, nr, lbl, 'HorizontalAlignment','center', ...
                    'VerticalAlignment','middle','FontSize',9,'FontWeight','bold','Color',clr);
            end
        end
    end
    set(gca,'XTick',1:n_stk,'XTickLabel',tick_lbl,'YTick',1:n_stk,'YTickLabel',tick_lbl, ...
        'YDir','normal','FontSize',7);
    xlabel('n_{RTG}'); ylabel('n_{Rogue}');
    title(sprintf('%s  [kNs]', fam_stk_I{fi,4})); ax();
end
sgtitle('Total deliverable impulse — stacking grid  (n_T does not affect I_{total})', ...
    'FontSize', 12, 'FontWeight', 'bold');
fig();

%% ── FIG 8: Family stacking — peak duty cycle (2×2 grid) ────────────────
% duty(n_R,n_T) = t_burst / (t_burst + n_R*E_store / (n_T*P_net_default))
% Default power source: Rogue family = RTG; Warlock = RTG+; SuperMag = RSG-200.
P_net_fam_stk = [rtg.P_design_W * mppt.eta - rtg.P_parasitic_W, ...   % Demo: RTG
                 rtg.P_design_W * mppt.eta - rtg.P_parasitic_W, ...   % Pub:  RTG
                 rtg_plus.P_design_W * mppt.eta - rtg.P_parasitic_W, ... % W: RTG+
                 NEP_SM.ops.P_net_W];                                % SM: RSG-200 (from ops struct)
E_store_fam = [rogue.E_store_J, rogue.E_store_J, NEP_W.E_store_J, NEP_SM.E_store_J];
t_burst_fam = [rogue.t_burst_max_s, NEP_RP.t_burst_s, NEP_W.t_burst_s, NEP_SM.t_burst_s];
pwr_lbl_fam = {'RTG', 'RTG', 'RTG+', 'RSG-200'};

figure('Name','Family stacking: duty cycle');
for fi = 1:4
    P_n   = P_net_fam_stk(fi);
    E_s   = E_store_fam(fi);
    t_b   = t_burst_fam(fi);
    duty_grid = zeros(n_stk, n_stk);
    for nr = 1:n_stk
        for nt = 1:n_stk
            t_rchg = nr * E_s / (nt * P_n);
            duty_grid(nr,nt) = t_b / (t_b + t_rchg) * 100;
        end
    end

    subplot(2,2,fi);
    imagesc(duty_grid); colormap(gca, parula);
    cb = colorbar; cb.Label.String = 'Duty cycle [%]';
    clim([0, min(max(duty_grid(:))*1.1, 100)]);
    hold on;
    for nr = 1:n_stk
        for nt = 1:n_stk
            v = duty_grid(nr,nt);
            clr = text_colour_for_value(v, duty_grid, false);
            text(nt, nr, sprintf('%.1f%%', v), 'HorizontalAlignment','center', ...
                'VerticalAlignment','middle','FontSize',9,'FontWeight','bold','Color',clr);
        end
    end
    set(gca,'XTick',1:n_stk,'XTickLabel',tick_lbl,'YTick',1:n_stk,'YTickLabel',tick_lbl, ...
        'YDir','normal','FontSize',11);
    xlabel('n_{RTG}'); ylabel('n_{Rogue}');
    title(sprintf('%s  [%s]', fam_stk{fi,4}, pwr_lbl_fam{fi})); ax();
end
sgtitle('Peak duty cycle — stacking grid  [default power source per variant]', ...
    'FontSize', 12, 'FontWeight', 'bold');
fig();
%% ── FIG 8b: Family stacking — system specific mass (2×2 grid) ───────────
% alpha_sys(n_R,n_T) = (n_R*m_thruster + n_T*m_pwr) / (n_T * P_net_per_unit)
% Spacecraft-independent: this is the propulsion-system metric (kg/We).
% Power source per variant matches Fig 8: Demo/Pub = RTG, Warlock = RTG+, SM = RSG-200.
P_net_RTG_fam = [rtg.P_design_W      * mppt.eta - rtg.P_parasitic_W, ...   % Demo: RTG
                 rtg.P_design_W      * mppt.eta - rtg.P_parasitic_W, ...   % Pub:  RTG
                 rtg_plus.P_design_W * mppt.eta - rtg.P_parasitic_W, ...   % W:    RTG+
                 rsg(3).P_design_W   * mppt.eta - rtg.P_parasitic_W];      % SM:   RSG-200
m_RTG_fam = [rtg.mass_kg, rtg.mass_kg, rtg_plus.mass_kg, rsg(3).mass_kg];

figure('Name','Family stacking: system specific mass');
for fi = 1:4
    m_thr_f = fam_stk{fi,3};
    P_n     = P_net_RTG_fam(fi);
    m_RTG_f = m_RTG_fam(fi);
    alpha_grid = zeros(n_stk, n_stk);
    for nr = 1:n_stk
        for nt = 1:n_stk
            m_sys = nr * m_thr_f + nt * m_RTG_f;
            P_tot = nt * P_n;
            alpha_grid(nr,nt) = m_sys / P_tot;   % kg/We
        end
    end

    subplot(2,2,fi);
    imagesc(alpha_grid); colormap(gca, parula);
    cb = colorbar; cb.Label.String = '\alpha_{sys} [kg/We]';
    hold on;
    for nr = 1:n_stk
        for nt = 1:n_stk
            v = alpha_grid(nr,nt);
            clr = text_colour_for_value(v, alpha_grid, false);
            text(nt, nr, sprintf('%.2f', v), 'HorizontalAlignment','center', ...
                'VerticalAlignment','middle','FontSize',9,'FontWeight','bold','Color',clr);
        end
    end
    set(gca,'XTick',1:n_stk,'XTickLabel',tick_lbl,'YTick',1:n_stk,'YTickLabel',tick_lbl, ...
        'YDir','normal','FontSize',7);
    xlabel('n_{RTG}'); ylabel('n_{Rogue}');
    title(sprintf('%s  [kg/We]', fam_stk{fi,4})); ax();
end
sgtitle('System specific mass — stacking grid  [\alpha_{sys} = m_{sys}/P_{net}]', ...
    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'tex');
fig();

%% ── FIG 9: Mission feasibility map (I_total vs alpha_RTG) ───────────────
figure('Name','Mission Feasibility map'); hold on; grid on; box on;
alpha_rtg_vec = logspace(log10(0.05), log10(3.0), 300);
I_avail_vec   = logspace(1, 7, 300);
for i = 1:n_prof
    th = sm.threshold(i);
    if isnan(th.alpha_power_max_kgWe), continue; end
    plot([alpha_rtg_vec(1), th.alpha_power_max_kgWe], [th.I_req_Ns, th.I_req_Ns], ...
        '-', 'LineWidth', 1.4, 'Color', prof_colors(i,:), 'HandleVisibility','off');
    plot([th.alpha_power_max_kgWe, th.alpha_power_max_kgWe], ...
        [th.I_req_Ns, I_avail_vec(end)], ...
        ':', 'LineWidth', 0.9, 'Color', prof_colors(i,:), 'HandleVisibility','off');
    text(th.alpha_power_max_kgWe * 1.04, th.I_req_Ns, mp(i).label, ...
        'FontSize', 8, 'Color', prof_colors(i,:), 'VerticalAlignment','middle', ...
        'Interpreter','none');
end
xline(rtg.specific_mass_kgWe, '--k', sprintf('Current %.2f kg/We', rtg.specific_mass_kgWe), ...
    'LabelOrientation','horizontal','LabelVerticalAlignment','bottom','LineWidth',1.5);
yline(NEP.I_total_current_Ns, ':',  'Color',[0.5 0.5 0.5], 'LineWidth',1.2, ...
    'DisplayName',sprintf('Rogue confirmed %.0f Ns', NEP.I_total_current_Ns));
yline(NEP.I_total_website_Ns, '--', 'Color',[0.3 0.5 0.8], 'LineWidth',1.2, ...
    'DisplayName',sprintf('Rogue propellant-implied ~%.0f Ns', NEP.I_total_website_Ns));
yline(50e3, '--', 'Color',[0.1 0.6 0.3], 'LineWidth',1.2, 'DisplayName','Warlock 50 kNs');
yline(1e6,  '--', 'Color',[0.8 0.3 0.1], 'LineWidth',1.2, 'DisplayName','SuperMagdrive 1 MNs');
set(gca,'XScale','log','YScale','log');
xlim([0.05 3.0]); ylim([10 1e7]);
xlabel('RTG specific mass \alpha_{RTG} [kg/We]');
ylabel('Total impulse available [Ns]');
title('Mission feasibility map');
subtitle(sprintf('Feasible region above-left of corner; %.0f%% s/c mass allowance', sm.f_prop_ref*100));
lgd = legend('Location','southeast'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 10: Mission unlock map — Magdrive family (2×2) ──────────────────
% Minimum n_R (thrusters) to close each profile at each n_T (power units).
% Dual constraint: pulse-life AND duty-cycle ceiling.
% Each profile uses its own m_sc_kg; row y-axes linked (same profile list).
% Default power per family: Rogue = RTG; Rogue pub = RTG; Warlock = RTG+; SM = RSG-200.
SPY_UM  = 365.25 * 24 * 3600;

fam_UM_lbl    = {'Rogue (demo)',  'Rogue (public)', 'Warlock (RTG+)',  'SuperMagdrive (RSG-200)'};
fam_UM_Ibit   = [rogue.I_bit_Ns,  NEP_RP.I_bit_Ns,  NEP_W.I_bit_Ns,   NEP_SM.I_bit_Ns];
fam_UM_Itot   = [rogue.I_bit_Ns*rogue.n_pulses_ambition, NEP_RP.I_total_Ns, NEP_W.I_total_Ns, NEP_SM.I_total_Ns];
fam_UM_E      = [rogue.E_store_J, rogue.E_store_J,   NEP_W.E_store_J,  NEP_SM.E_store_J];
fam_UM_tburst = [rogue.t_burst_max_s, NEP_RP.t_burst_s, NEP_W.t_burst_s, NEP_SM.t_burst_s];
fam_UM_Fmn    = [rogue.I_bit_Ns*rogue.f_Hz*1e3, NEP_RP.F_max_mN, NEP_W.F_max_mN, NEP_SM.F_max_mN];
fam_UM_Pnet   = [rtg.P_design_W*mppt.eta      - rtg.P_parasitic_W, ...  % Demo:  RTG
                 rtg.P_design_W*mppt.eta      - rtg.P_parasitic_W, ...  % Pub:   RTG
                 rtg_plus.P_design_W*mppt.eta - rtg.P_parasitic_W, ...  % W:     RTG+
                 NEP_SM.ops.P_net_W];                                    % SM:    RSG-200
fam_UM_Isp    = [rogue.Isp_s, NEP_RP.Isp_s, NEP_W.Isp_s, NEP_SM.Isp_s];
fam_UM_mthr   = [rogue.mass_kg, rogue.mass_kg, NEP_W.m_thruster_kg, NEP_SM.m_thruster_kg];
fam_UM_mpwr   = [rtg.mass_kg,   rtg.mass_kg,   rtg_plus.mass_kg,    NEP_SM.power.m_kg];

figure('Name', 'Mission unlock map');
tl_UM = tiledlayout(2, 2, 'TileSpacing','compact', 'Padding','compact');
ax_UM = gobjects(4,1);

for fi = 1:4
    unlock_fi = NaN(n_prof, n_stk);
    for i = 1:n_prof
        dV_r = mp(i).dV_req_ms;
        m_sc = mp(i).m_sc_kg;
        for nt = 1:n_stk
            for nr = 1:n_stk
                m_sys = nr * fam_UM_mthr(fi) + nt * fam_UM_mpwr(fi);
                if m_sys >= m_sc, continue; end
                I_del  = min(nr * fam_UM_Ibit(fi) * 10e6, nr * fam_UM_Itot(fi));
                m_prop = min(I_del / (fam_UM_Isp(fi)*g0), (m_sc - m_sys) * 0.999);
                dV_lif = fam_UM_Isp(fi) * g0 * log(m_sc / max(m_sc - m_prop, 1e-9));
                t_rchg = nr * fam_UM_E(fi) / (nt * fam_UM_Pnet(fi));
                duty   = fam_UM_tburst(fi) / (fam_UM_tburst(fi) + t_rchg);
                dV_dut = fam_UM_Fmn(fi) * 1e-3 * duty * SPY_UM / m_sc;
                if dV_lif >= dV_r && dV_dut >= dV_r
                    unlock_fi(i, nt) = nr;
                    break;
                end
            end
        end
    end

    ax_UM(fi) = nexttile(tl_UM); hold on;
    imagesc(unlock_fi, [1 n_stk]);
    colormap(gca, flipud(summer(n_stk)));
    cb = colorbar; cb.Label.String = 'Min n_R'; cb.Ticks = 1:n_stk;
    for i = 1:n_prof
        if all(isnan(unlock_fi(i,:)))
            patch([0.5 n_stk+0.5 n_stk+0.5 0.5], [i-0.5 i-0.5 i+0.5 i+0.5], ...
                'r', 'FaceAlpha', 0.3, 'EdgeColor','none', 'HandleVisibility','off');
            text(n_stk/2, i, 'INFEAS', 'HorizontalAlignment','center', ...
                'FontSize', 7, 'FontWeight','bold', 'Color', [0.6 0 0]);
        end
    end
    set(gca, 'YTick',1:n_prof, 'YTickLabel',prof_labels, ...
        'XTick',1:n_stk, 'XTickLabel',string(1:n_stk), ...
        'YDir','normal', 'TickLabelInterpreter','none', 'FontSize',7);
    if mod(fi,2) == 0, set(gca,'YTickLabel',{}); end
    xlabel('n_{power}');
    if mod(fi,2) == 1, ylabel('Mission profile'); end
    title(fam_UM_lbl{fi}, 'FontWeight','bold', 'FontSize', 9);
    ax(); hold off;
end
linkaxes(ax_UM, 'y');
title(tl_UM, 'Mission unlock map — Magdrive family  (profile-own m_{sc}, dual constraint, 10M pulses)', ...
    'FontSize', 10, 'FontWeight', 'bold');
fig();

%% ── FIG 11: Stacking scaling curves ────────────────────────────────────
n_rtg_show = [1, 2, 3, 5];
ls_stk     = {'-','--','-.', ':'};
m_ref_stk2 = stk_m_sc(1);

figure('Name','Stacking scaling');
subplot(1,2,1); hold on; grid on;
dV_line = arrayfun(@(nr) stk(nr,1).dV_life_ms(1), 1:n_stk);
plot(1:n_stk, dV_line, '-o', 'LineWidth', 2.5, 'Color', C(1,:), 'MarkerFaceColor',C(1,:), ...
    'DisplayName', sprintf('Lifetime \\DeltaV (%.0f kg)', m_ref_stk2));
for k = 1:n_prof
    yline(mp(k).dV_req_ms, ':k', 'HandleVisibility','off');
    text(n_stk+0.1, mp(k).dV_req_ms, mp(k).label, 'FontSize', 8, ...
        'Color',[0.4 0.4 0.4], 'VerticalAlignment','middle', 'Interpreter','none');
end
set(gca,'XTick',1:n_stk); xlim([0.7, n_stk+1.5]);
xlabel('n_{Rogue}'); ylabel('Lifetime \DeltaV [m/s]');
title('\DeltaV vs n_{Rogue}');
lgd = legend('Location','northwest'); style_legend(lgd); ax();

subplot(1,2,2); hold on; grid on;
for ki = 1:numel(n_rtg_show)
    nt = n_rtg_show(ki);
    duty_line = arrayfun(@(nr) stk(nr,nt).duty*100, 1:n_stk);
    plot(1:n_stk, duty_line, ls_stk{ki}, 'LineWidth', 2, 'Color', C(ki,:), ...
        'DisplayName', sprintf('n_{RTG} = %d', nt));
end
set(gca,'XTick',1:n_stk);
xlabel('n_{Rogue}'); ylabel('Duty cycle [%]');
title('Duty cycle vs n_{Rogue}');
lgd = legend('Location','northwest'); style_legend(lgd); ax();

sgtitle(sprintf('Stacking scaling curves (%.0f kg s/c, I_{bit} = %.0f uN.s)', ...
    m_ref_stk2, rogue.I_bit_Ns*1e6), 'FontSize', 11, 'FontWeight', 'bold');
fig(); hold off;

%% ── FIG 12: Frequency sweep (F = I_bit x f invariance) ─────────────────
figure('Name','Frequency sweep');
f_vals  = [NEP.sw_freq.f_Hz];
dV_f    = [NEP.sw_freq.dV_ms];    dV_f(isnan(dV_f)) = 0;
duty_f  = [NEP.sw_freq.duty]*100;
t_max_f = [NEP.sw_freq.t_max_s];
life_f  = [NEP.sw_freq.life_10M_days];

subplot(2,2,1); hold on; grid on;
bar(1:numel(f_vals), t_max_f, 0.5, 'FaceColor', C(5,:));
set(gca,'XTick',1:numel(f_vals),'XTickLabel',string(f_vals)+" Hz");
ylabel('Max burst [s]'); title('Burst duration'); ax();

subplot(2,2,2); hold on; grid on;
bar(1:numel(f_vals), duty_f, 0.5, 'FaceColor', C(1,:));
% Reference lines: operating-point duty cycle for other family members (RTG+)
if exist('NEP_RP','var'), yline(NEP_RP.ops.duty_pct,  '--','Color',[0.2 0.6 0.9],'Label','Pub RTG', 'LabelOrientation','horizontal','HandleVisibility','off'); end
if exist('NEP_W', 'var'), yline(NEP_W.ops_rtg_plus.duty_pct,'--','Color',[0.9 0.5 0.1],'Label','Warlock RTG+','LabelOrientation','horizontal','HandleVisibility','off'); end
if exist('NEP_SM','var'), yline(NEP_SM.ops_rsg200.duty_pct, '--','Color',[0.6 0.1 0.7],'Label','SM RSG-200','LabelOrientation','horizontal','HandleVisibility','off'); end
set(gca,'XTick',1:numel(f_vals),'XTickLabel',string(f_vals)+" Hz");
ylabel('Duty cycle [%]'); title('Duty cycle  (family refs dashed)'); ax();

subplot(2,2,3); hold on; grid on;
bar(1:numel(f_vals), dV_f, 0.5, 'FaceColor', C(3,:));
yline(NEP.dV_duty_ceiling,'--r',sprintf('Ceiling %.1f', NEP.dV_duty_ceiling), ...
    'HandleVisibility','off','LabelOrientation','horizontal');
set(gca,'XTick',1:numel(f_vals),'XTickLabel',string(f_vals)+" Hz");
ylabel('\DeltaV [m/s/yr]'); title('Annual \DeltaV'); ax();

subplot(2,2,4); hold on; grid on;
bar(1:numel(f_vals), life_f, 0.5, 'FaceColor', C(4,:));
yline(365,'--k','1 yr','HandleVisibility','off','LabelOrientation','horizontal');
set(gca,'XTick',1:numel(f_vals),'XTickLabel',string(f_vals)+" Hz");
ylabel('Calendar life [days]'); title('Lifetime @ 10M'); ax();

sgtitle('Frequency sweep: F = I_{bit} \times f', 'FontSize', 12, 'FontWeight', 'bold');
fig();

%% ── FIG 13: E_pulse -> I_bit scaling (alpha sweep) ─────────────────────
figure('Name','E_pulse scaling');
alpha_labels = {'\alpha = 0.5','\alpha = 0.7','\alpha = 1.0'};
ls_a = {':','--','-'};

subplot(1,2,1); hold on; grid on;
for ai = 1:numel(cfg.alpha_sweep)
    plot(cfg.E_pulse_sweep_J, NEP.sw_epulse.I_bit_grid(ai,:)*1e6, ls_a{ai}, ...
        'LineWidth', 2, 'Color', C(ai,:), 'DisplayName', alpha_labels{ai});
end
plot(rogue.E_per_pulse_J, rogue.I_bit_Ns*1e6, 'ko', 'MarkerSize', 8, ...
    'MarkerFaceColor','k', 'DisplayName', sprintf('Reference %.0f J', rogue.E_per_pulse_J));
xlabel('E_{pulse} [J]'); ylabel('I_{bit} [uN.s]');
title('I_{bit} vs pulse energy'); lgd = legend; style_legend(lgd); ax();

subplot(1,2,2); hold on; grid on;
for ai = 1:numel(cfg.alpha_sweep)
    dV_ep = NEP.sw_epulse.dV_life_grid(ai,:); dV_ep(isnan(dV_ep)) = 0;
    plot(cfg.E_pulse_sweep_J, dV_ep, ls_a{ai}, ...
        'LineWidth', 2, 'Color', C(ai,:), 'DisplayName', alpha_labels{ai});
end
plot(rogue.E_per_pulse_J, NEP.dV_cap_10M_ms, 'ko', 'MarkerSize', 8, ...
    'MarkerFaceColor','k', 'DisplayName', 'Reference');
xlabel('E_{pulse} [J]'); ylabel(sprintf('Lifetime \\DeltaV [m/s]'));
title('Lifetime \DeltaV vs pulse energy'); lgd = legend; style_legend(lgd); ax();

sgtitle(sprintf('E_{pulse} \\rightarrow I_{bit} scaling (%.0f kg s/c, 10M pulses)', cfg.m_ref_kg), ...
    'FontSize', 12, 'FontWeight', 'bold');
fig(); hold off;

%% ── FIG 14: Store size scaling ─────────────────────────────────────────
% Burst and recharge times scale linearly with store; duty and per-cycle dV
% follow from those. Reflects the corrected Section M physics: duty is
% independent of store size at fixed pulse parameters.
figure('Name','Store size scaling');
E_kJ = NEP.sw_store.E_store_J / 1e3;

subplot(1,2,1); hold on; grid on;
plot(E_kJ, NEP.sw_store.t_burst_s, '-', 'LineWidth', 2, 'Color', C(1,:), ...
    'DisplayName', 'Burst t_{burst}');
plot(E_kJ, NEP.sw_store.t_rchg_s, '--', 'LineWidth', 2, 'Color', C(2,:), ...
    'DisplayName', 'Recharge t_{rchg}');
plot(E_kJ, NEP.sw_store.t_cycle_s, ':', 'LineWidth', 1.5, 'Color', C(3,:), ...
    'DisplayName', 'Cycle period');
xline(rogue.E_store_J/1e3, '--k', sprintf('%.0f kJ', rogue.E_store_J/1e3), ...
    'LabelOrientation','horizontal','HandleVisibility','off');
set(gca,'XScale','log','YScale','log');
xlabel('E_{store} [kJ]'); ylabel('Time [s]');
title('Burst and recharge scaling');
lgd = legend('Location','northwest'); style_legend(lgd); ax();

subplot(1,2,2); hold on; grid on;
yyaxis left;
plot(E_kJ, NEP.sw_store.dV_per_cycle_ms, '-', 'LineWidth', 2, 'Color', C(1,:), ...
    'DisplayName', 'Per-cycle \DeltaV');
ylabel('Per-cycle \DeltaV [m/s]'); set(gca,'YColor','k');
yyaxis right;
plot(E_kJ, NEP.sw_store.duty*100, '--', 'LineWidth', 1.5, 'Color', C(5,:), ...
    'DisplayName', 'Duty cycle');
ylabel('Duty cycle [%]'); set(gca,'YColor',C(5,:));
ylim([0, max(NEP.sw_store.duty*100)*1.2]);
set(gca,'XScale','log');
xlabel('E_{store} [kJ]');
title('Per-cycle \DeltaV and duty');
lgd = legend('Location','northwest'); style_legend(lgd); ax();

sgtitle(sprintf('Store size scaling at fixed E_{pulse} = %.0f J, f = %.0f Hz', ...
    rogue.E_per_pulse_J, rogue.f_Hz), 'FontSize', 12, 'FontWeight', 'bold');
fig(); hold off;

%% ── FIG 15: Lifetime heatmaps (surf+view(2) on log axes) ───────────────
figure('Name','Lifetime heatmaps');
[F1, E1] = meshgrid(lfe.f_Hz,  lfe.E_store_J/1e3);
[F2, P2] = meshgrid(lfep.f_Hz, lfep.E_pulse_J);

subplot(1,3,1);
surf(F1, E1, lfe.life_10M', 'EdgeColor','none'); view(2);
set(gca,'XScale','log','YScale','log');
colorbar; colormap(gca,'hot');
xlabel('f [Hz]'); ylabel('E_{store} [kJ]');
title('Calendar life @ 10M [days]');
subtitle('E_{pulse} = 4 J fixed');
ax();

subplot(1,3,2);
surf(F2, P2, lfep.life_10M', 'EdgeColor','none'); view(2);
set(gca,'XScale','log','YScale','log');
colorbar; colormap(gca,'hot');
xlabel('f [Hz]'); ylabel('E_{pulse} [J]');
title('Calendar life @ 10M [days]');
subtitle('E_{store} = 8 kJ fixed');
ax();

subplot(1,3,3);
dV_g = lfep.dV_life_10M; dV_g(isnan(dV_g)) = 0;
surf(F2, P2, dV_g', 'EdgeColor','none'); view(2);
set(gca,'XScale','log','YScale','log');
colorbar; colormap(gca,'parula');
xlabel('f [Hz]'); ylabel('E_{pulse} [J]');
title(sprintf('Lifetime \\DeltaV @ 10M [m/s]'));
subtitle(sprintf('I_{bit} \\propto E_{pulse}^{%.1f}', cfg.alpha_Ipulse));
ax();

sgtitle('Lifetime heatmaps (log axes)', 'FontSize', 12, 'FontWeight', 'bold');
fig();

%% ── FIG 16: Recharge time vs RTG power ─────────────────────────────────
figure('Name','Recharge vs RTG power'); hold on; grid on;
for i = 1:numel(NEP.sw_pwr.E_store_J)
    plot(NEP.sw_pwr.P_RTG_W, NEP.sw_pwr.t_recharge_grid(i,:)/60, ...
        'LineWidth', 1.8, 'Color', C(i,:), ...
        'DisplayName', sprintf('%.0f kJ', NEP.sw_pwr.E_store_J(i)/1e3));
end
xline(rtg.P_design_W, '--k', sprintf('%.0f We design', rtg.P_design_W), ...
    'LabelOrientation','horizontal','HandleVisibility','off','LineWidth',1.2);
xlabel('RTG output [We]'); ylabel('Recharge time [min]');
title('Recharge time vs RTG power');
lgd = legend; style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 17: RTG power sensitivity ──────────────────────────────────────
n_cases = numel(NEP.sw_power);
P_lbl = {'Lab min', 'Lab max', 'Design', 'RTG+'};
P_lbl = P_lbl(1:n_cases);

dv_p = [NEP.sw_power.dV_ms]; dv_p(isnan(dv_p)) = 0;
sp_vals  = { [NEP.sw_power.t_min], [NEP.sw_power.duty]*100, dv_p };
sp_ylbl  = { 'Recharge [min]', 'Duty cycle [%]', '\DeltaV [m/s/yr]' };
sp_title = { 'Recharge time',  'Duty cycle',     'Duty-limited \DeltaV' };

figure('Name','RTG power sensitivity');
for sp = 1:3
    subplot(1,3,sp);
    bar(1:n_cases, sp_vals{sp}, 0.5, 'FaceColor', C(sp,:)); grid on;
    set(gca, 'XTick', 1:n_cases, 'XTickLabel', P_lbl, ...
        'XTickLabelRotation', 30);
    ylabel(sp_ylbl{sp}); title(sp_title{sp}); ax();
end
sgtitle('RTG power sensitivity', 'FontSize', 12, 'FontWeight', 'bold');
fig();

%% ── FIG 18: TEG characterisation ───────────────────────────────────────
figure('Name','TEG characterisation');
subplot(1,2,1); hold on; grid on;
yyaxis left;
plot(teg.T_cold_C, teg.P_max_W, '-o', 'LineWidth',1.8,'Color',C(1,:),'MarkerFaceColor',C(1,:));
ylabel('Single TEG [We]'); set(gca,'YColor',C(1,:));
yyaxis right;
plot(teg.T_cold_C, teg.P_total_W, '-s', 'LineWidth',1.8,'Color',C(2,:),'MarkerFaceColor',C(2,:));
ylabel(sprintf('RTG total %d TEG [We]', rtg.n_TEG)); set(gca,'YColor',C(2,:));
xline(rtg.T_housing_C, '--k', sprintf('Housing ~%d^{\\circ}C', rtg.T_housing_C), ...
    'HandleVisibility','off','LabelOrientation','horizontal');
xlabel('Cold-side temperature [^{\circ}C]');
title('TEG power vs cold-side temperature');
legend({'Single TEG','RTG total'},'Location','northwest'); ax();

subplot(1,2,2); hold on; grid on;
plot(teg.delta_T_C, teg.eta_pct, '-o', 'LineWidth',1.8,'Color',C(3,:),'MarkerFaceColor',C(3,:));
xlabel('\DeltaT [^{\circ}C]'); ylabel('TEG efficiency [%]');
title('TEG efficiency vs \DeltaT'); ax();

sgtitle(sprintf('TEG characterisation (UL-RTG-IS-0001 Table 4-5, %d modules)', rtg.n_TEG), ...
    'FontSize', 12, 'FontWeight', 'bold');
fig(); hold off;

%% ── FIG 19: Isp sensitivity ────────────────────────────────────────────
% Lifetime dV at 10M pulses, conservative I_bit, varying Isp.
figure('Name','Isp sensitivity'); hold on; grid on;
Isp_arr = [NEP.sw_Isp.Isp_s];
dV_arr  = [NEP.sw_Isp.dV_ref_ms]; dV_arr(isnan(dV_arr)) = 0;
N_imp   = [NEP.sw_Isp.N_implied_M];

bar(1:numel(Isp_arr), dV_arr, 0.55, 'FaceColor', C(1,:), 'DisplayName', 'Lifetime \DeltaV');
xline(find(Isp_arr == rogue.Isp_s), '--k', 'Reference Isp', ...
    'LabelOrientation','horizontal','HandleVisibility','off');
set(gca,'XTick',1:numel(Isp_arr),'XTickLabel', string(Isp_arr) + " s");
ylabel('Lifetime \DeltaV [m/s]');
yyaxis right;
plot(1:numel(Isp_arr), N_imp, '-o', 'LineWidth', 1.5, 'Color', C(3,:), ...
    'MarkerFaceColor', C(3,:), 'DisplayName', 'Implied N_{pulses} for 200 g prop');
ylabel('Implied N_{pulses} [M]'); set(gca,'YColor', C(3,:));
xlabel('Specific impulse');
title('Isp sensitivity');
subtitle(sprintf('%.0f kg s/c, 10M pulses, I_{bit} = %.0f uN.s', ...
    cfg.m_ref_kg, rogue.I_bit_Ns*1e6));
lgd = legend('Location','northwest'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 20: Mass budget ────────────────────────────────────────────────
figure('Name','Mass budget'); hold on; grid on;
mass_items = {'RTG', 'Rogue', 'Coupling', 'MPPT'};
mass_vals  = [NEP.mass.rtg_kg, NEP.mass.rogue_kg, NEP.mass.coupling_kg, NEP.mass.mppt_kg];
mass_known = ~isnan(mass_vals);
b = bar(1:numel(mass_items), mass_vals, 0.5);
b.FaceColor = 'flat';
for i = 1:numel(mass_items)
    if mass_known(i), b.CData(i,:) = C(1,:); else, b.CData(i,:) = [0.7 0.7 0.7]; end
end
for i = 1:numel(mass_items)
    if mass_known(i)
        text(i, mass_vals(i), sprintf(' %.2f kg', mass_vals(i)), ...
            'VerticalAlignment', 'bottom', 'HorizontalAlignment','center', 'FontSize', 9);
    else
        text(i, 0.5, 'pending', 'VerticalAlignment','bottom', ...
            'HorizontalAlignment','center', 'FontSize', 9, 'Color', [0.4 0.4 0.4]);
    end
end
set(gca, 'XTick', 1:numel(mass_items), 'XTickLabel', mass_items);
ylabel('Mass [kg]');
title('Propulsion-system mass budget');
subtitle(sprintf('Known total %.2f kg (RTG + Rogue)', NEP.mass.total_kg));
ax(); fig(); hold off;

%% ── FIGS 21-28: FAMILY COMPARISON ──────────────────────────────────────
% Figs 21-28 require NEP_RP, NEP_W, NEP_SM. Fig 24 also needs ep; Fig 29
% (after this block) additionally needs the family struct.
fam_ok = exist('NEP_RP','var') && exist('NEP_W','var') && exist('NEP_SM','var');

if ~fam_ok
    fprintf('  [Figs 21-28 skipped: run Rogue_Public, Warlock, SuperMag first]\n');
else

% Family data assembly (kept local to plotting; mirrors Family_Compare).
fam_labels  = {'Rogue (conf.)', 'Rogue (pub.)', 'Warlock', 'SuperMag'};
fam_colors  = [0.20 0.40 0.70;     % conservative blue
               0.20 0.65 0.85;     % public-spec light blue
               0.95 0.55 0.20;     % warlock orange
               0.75 0.20 0.60];    % supermag magenta

I_bit_lo = [rogue.I_bit_Ns,                 NEP_RP.cfg.I_bit_from_F, ...
            NEP_W.cfg.I_bit_from_F,         NEP_SM.cfg.I_bit_from_F] * 1e6;
I_bit_hi = [rogue.I_bit_Ns,                 NEP_RP.cfg.I_bit_from_IT, ...
            NEP_W.cfg.I_bit_from_IT,        NEP_SM.cfg.I_bit_from_IT] * 1e6;
I_total  = [rogue.I_bit_Ns * rogue.n_pulses_ambition, ...
            NEP_RP.I_total_Ns, NEP_W.I_total_Ns, NEP_SM.I_total_Ns];

%% ── FIG 21: Family I_bit and I_total step-up ──────────────────────────
figure('Name','Family I_bit step-up');
subplot(1,2,1); hold on; grid on;
x = 1:4; bw = 0.35;
b1 = bar(x - bw/2, I_bit_lo, bw, 'FaceColor','flat', 'DisplayName','Conservative (F_{max}/f)');
b2 = bar(x + bw/2, I_bit_hi, bw, 'FaceColor','flat', 'DisplayName','Optimistic (I_{total}/10M)');
for i = 1:4
    b1.CData(i,:) = fam_colors(i,:) * 0.7;
    b2.CData(i,:) = fam_colors(i,:);
end
set(gca, 'XTick', x, 'XTickLabel', fam_labels, 'YScale','log');
ylabel('I_{bit} [uN.s]');
title('Impulse bit derivations');
lgd = legend('Location','northwest'); style_legend(lgd); ax();

subplot(1,2,2); hold on; grid on;
b3 = bar(x, I_total, 0.55, 'FaceColor','flat');
for i = 1:4, b3.CData(i,:) = fam_colors(i,:); end
for i = 1:4
    text(x(i), I_total(i), sprintf(' %.0fx', I_total(i)/I_total(1)), ...
        'VerticalAlignment','bottom', 'HorizontalAlignment','center', ...
        'FontSize', 9, 'FontWeight', 'bold');
end
set(gca, 'XTick', x, 'XTickLabel', fam_labels, 'YScale','log');
ylabel('I_{total} [Ns]');
title('Total impulse step-up');
ax();

sgtitle('Magdrive family: I_{bit} and I_{total} across the product line', ...
    'FontSize', 12, 'FontWeight', 'bold');
fig();

%% ── FIG 22: Family duty cycle across power options ────────────────────
% Rows: Rogue conf, Rogue pub, Warlock, SuperMag.
% Columns: RTG (10 We), RTG+ (40 We), RSG mid, RSG high.
%   Rogue family RTG+ uses Rogue E_store (8 kJ) — computed inline below.
%   Warlock RTG+ = ops_rtg_plus (50 kJ E_store, from the variant script).
%   SuperMag RTG+ = ops_rtg_plus (2 MJ E_store, from the variant script).
%   RSG labels: Warlock col 3/4 = RSG-35/RSG-100; SuperMag col 3/4 = RSG-100/RSG-200.
figure('Name','Family duty cycle'); hold on; grid on;
duty_data = NaN(4, 4);   % rows: thrusters, cols: RTG / RTG+ / RSG-mid / RSG-high

% Rogue family RTG+ is safe to compute inline (shares rogue.E_store_J).
rchg_duty_rogue = @(P_e, t_burst) ...
    t_burst / (t_burst + rogue.E_store_J / (P_e * mppt.eta - rtg.P_parasitic_W)) * 100;

duty_data(1,1) = NEP.rc_max.duty_cycle * 100;
duty_data(1,2) = rchg_duty_rogue(rtg_plus.P_design_W, rogue.t_burst_max_s);
duty_data(2,1) = NEP_RP.ops.duty_pct;
duty_data(2,2) = rchg_duty_rogue(rtg_plus.P_design_W, NEP_RP.ops.t_burst_s);
duty_data(3,1) = NEP_W.ops_rtg.duty_pct;
duty_data(3,2) = NEP_W.ops_rtg_plus.duty_pct;       % Warlock RTG+ — uses W E_store (50 kJ)
duty_data(3,3) = NEP_W.ops_rsg35.duty_pct;           % RSG-35
duty_data(3,4) = NEP_W.ops_rsg100.duty_pct;          % RSG-100
duty_data(4,1) = NEP_SM.ops_rtg.duty_pct;
duty_data(4,2) = NEP_SM.ops_rtg_plus.duty_pct;       % SuperMag RTG+ — uses SM E_store (2 MJ)
duty_data(4,3) = NEP_SM.ops_rsg100.duty_pct;         % RSG-100 (mid for SM scale)
duty_data(4,4) = NEP_SM.ops_rsg200.duty_pct;         % RSG-200 (high for SM scale)

power_labels = {'RTG (10 We)', 'RTG+ (40 We)', 'RSG-35 / RSG-100', 'RSG-100 / RSG-200'};
b = bar(1:4, duty_data, 0.85);
for i = 1:numel(b)
    b(i).DisplayName = power_labels{i};
end
set(gca, 'XTick', 1:4, 'XTickLabel', fam_labels, 'YScale','log');
ylabel('Duty cycle [%]');
title('Duty cycle across power options');
subtitle('Warlock RSG cols = RSG-35 / RSG-100;  SuperMag RSG cols = RSG-100 / RSG-200');
lgd = legend('Location','northwest'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 23: Family lifetime dV vs spacecraft mass ─────────────────────
figure('Name','Family lifetime dV'); hold on; grid on;
m_sweep_kg = logspace(log10(25), log10(2000), 100);
for f = 1:4
    switch f
        case 1, I_bit_f = rogue.I_bit_Ns;       Isp_f = rogue.Isp_s;     N_f = rogue.n_pulses_ambition;
        case 2, I_bit_f = NEP_RP.I_bit_Ns;      Isp_f = NEP_RP.Isp_s;    N_f = NEP_RP.cfg.n_pulses_at_spec;
        case 3, I_bit_f = NEP_W.I_bit_Ns;       Isp_f = NEP_W.Isp_s;     N_f = NEP_W.cfg.n_pulses_at_spec;
        case 4, I_bit_f = NEP_SM.I_bit_Ns;      Isp_f = NEP_SM.Isp_s;    N_f = NEP_SM.cfg.n_pulses_at_spec;
    end
    m_p = I_bit_f * N_f / (Isp_f * g0);
    dV  = Isp_f * g0 * log(m_sweep_kg ./ max(m_sweep_kg - m_p, eps));
    dV(m_sweep_kg <= m_p) = NaN;
    plot(m_sweep_kg, dV, '-', 'LineWidth', 2.2, 'Color', fam_colors(f,:), ...
        'DisplayName', fam_labels{f});
end
set(gca,'XScale','log','YScale','log');
xlabel('Spacecraft wet mass [kg]');
ylabel('Lifetime \DeltaV [m/s]');
title('Family lifetime \DeltaV vs spacecraft mass');
subtitle('Conservative I_{bit}, 10M pulses');
lgd = legend('Location','northeast'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 24: Family feasibility heatmap (requires ep) ──────────────────
if exist('ep','var')
    figure('Name','Family feasibility'); hold on;
    cfg_labels = {'Rogue demo x1', 'Rogue demo x3', 'Rogue demo x5', ...
                  'Rogue pub x1',  'Warlock x1',    'SuperMag x1'};
    pulse_labels = {'1M', '10M', '50M'};
    n_pulse_screen = [1e6, 10e6, 50e6];
    n_cfg = numel(cfg_labels);
    n_col = numel(n_pulse_screen);
    closure = zeros(n_cfg, n_col);
    I_req_all = arrayfun(@(x) x.I_total_req_Ns, ep);
    n_all_ep = numel(ep);
    for c = 1:n_col
        N = n_pulse_screen(c);
        I_del = [rogue.I_bit_Ns*1*N, rogue.I_bit_Ns*3*N, rogue.I_bit_Ns*5*N, ...
                 NEP_RP.I_total_Ns, NEP_W.I_total_Ns, NEP_SM.I_total_Ns];
        for ci = 1:n_cfg
            closure(ci, c) = sum(I_del(ci) >= I_req_all);
        end
    end

    imagesc(closure, [0 n_all_ep]); colormap(parula);
    cb = colorbar; cb.Label.String = sprintf('Profiles closed / %d', n_all_ep);
    for ci = 1:n_cfg
        for c = 1:n_col
            v = closure(ci, c);
            nrm = v / max(n_all_ep, 1);
            clr = [nrm < 0.55, nrm < 0.55, nrm < 0.55];
            text(c, ci, sprintf('%d', v), 'HorizontalAlignment','center', ...
                'VerticalAlignment','middle','FontSize',10,'FontWeight','bold','Color',clr);
        end
    end
    set(gca,'XTick',1:n_col,'XTickLabel',pulse_labels, ...
            'YTick',1:n_cfg,'YTickLabel',cfg_labels, ...
            'YDir','normal','TickLabelInterpreter','none');
    xlabel('Pulse budget');
    title('Family feasibility heatmap');
    ax(); fig(); hold off;
else
    fprintf('  [Fig 24 skipped: run MicroNEP_Extended_Profiles.m for ep struct]\n');
end

%% ── FIG 25: Family total impulse screen ─────────────────────────────────
% Per-mission required total impulse with vertical lines for each thruster
% (and selected stack configurations). Missions left of a line are covered
% on total impulse; duty-cycle constraint is in Figs 4 and 22.
figure('Name','Family impulse screen'); hold on; grid on;

% Capacity lines: Rogue confirmed pulse model, 5x stack, Rogue public, Warlock, SuperMag.
I_rogue_5x  = 5 * rogue.I_bit_Ns * rogue.n_pulses_ambition;
cap_labels  = {sprintf('Rogue demo (%.0f Ns)', NEP.I_total_current_Ns), ...
               sprintf('5x Rogue (%.0f Ns)', I_rogue_5x), ...
               sprintf('Rogue public (%.0f kNs)', NEP_RP.I_total_Ns/1e3), ...
               sprintf('Warlock (%.0f kNs)', NEP_W.I_total_Ns/1e3), ...
               sprintf('SuperMagdrive (%.0f MNs)', NEP_SM.I_total_Ns/1e6)};
cap_I_Ns    = [NEP.I_total_current_Ns, I_rogue_5x, NEP_RP.I_total_Ns, NEP_W.I_total_Ns, NEP_SM.I_total_Ns];
cap_colors  = {[0.45 0.45 0.45], [0.30 0.30 0.30], fam_colors(2,:), fam_colors(3,:), fam_colors(4,:)};
cap_ls      = {':', '-', '--', '--', '--'};
cap_lw      = [1.8, 2.2, 2.0, 2.0, 2.0];

% Capacity lines with labels placed OFF the line (offset right + staggered
% vertically) so adjacent labels do not overlap. Larger font for readability.
cap_short = {'Rogue demo', '5x Rogue', 'Rogue public', 'Warlock', 'SuperMag'};
% Staggered y-heights (reversed axis: larger = nearer top). Alternate to
% separate the closely-spaced Rogue demo / 5x Rogue / Rogue public labels.
cap_ylab  = [n_prof+0.95, n_prof+0.30, n_prof+0.95, n_prof+0.95, n_prof+0.95];
for j = 1:numel(cap_I_Ns)
    xline(cap_I_Ns(j), cap_ls{j}, 'Color', cap_colors{j}, ...
          'LineWidth', cap_lw(j), 'HandleVisibility', 'off');
    text(cap_I_Ns(j)*1.25, cap_ylab(j), cap_short{j}, ...
         'Color', cap_colors{j}, 'FontSize', 11, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
         'Interpreter', 'none');
end

% Mission requirements scattered against profile labels.
I_req_mp = [mp.I_req_Ns];
y_mp     = 1:n_prof;
h_dot    = scatter(I_req_mp, y_mp, 55, 'k', 'filled', 'DisplayName', 'Mission I_{req}');

set(gca, 'XScale', 'log', ...
         'YTick', y_mp, 'YTickLabel', prof_labels, ...
         'YDir', 'reverse', 'TickLabelInterpreter','none');
xlim([20, max(cap_I_Ns)*3]);
ylim([0.3, n_prof + 1.6]);   % extra headroom for the offset line labels
xlabel('Required total impulse I_{req} [Ns]');
title('Family total impulse screen');
subtitle('Missions left of a line are covered on I_{total}');
lgd = legend(h_dot, 'Location','southeast'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 26: Warlock system mass vs power-unit count ───────────────────
% RTG and three RSG tiers paired with Warlock; mass-fraction reference lines
% at 10 / 20 / 30 % of a 100 kg reference s/c.
figure('Name','Warlock power-unit mass'); hold on; grid on;
n_pwr_plot = 1:5;
m_sc_ref_w = NEP_W.ops.m_sc_ref_kg;

% RTG line (always available).
m_sys_rtg = NEP_W.m_thruster_kg + n_pwr_plot * rtg.mass_kg;
plot(n_pwr_plot, m_sys_rtg, '-o', 'LineWidth',2, 'Color',fam_colors(1,:), ...
    'MarkerFaceColor',fam_colors(1,:), 'DisplayName','Warlock + RTG');

% RSG-35 and RSG-100 lines using NEP_W's stored RSG configs.
rsg_configs = {NEP_W.power_rsg35,  NEP_W.power_rsg100};
rsg_styles  = {'--', '-.'};
rsg_color_idx = [3, 4];
for r = 1:numel(rsg_configs)
    rsg = rsg_configs{r};
    m_sys_rsg = NEP_W.m_thruster_kg + n_pwr_plot * rsg.m_kg;
    plot(n_pwr_plot, m_sys_rsg, rsg_styles{r}, 'LineWidth',2, 'Color',C(rsg_color_idx(r),:), ...
        'DisplayName', sprintf('Warlock + %s (%.0f We)', rsg.type, rsg.P_e_W));
end

% Mass-fraction reference lines.
for frac = [0.10, 0.20, 0.30]
    yline(frac*m_sc_ref_w, ':k', sprintf('%.0f%% of %.0f kg s/c', frac*100, m_sc_ref_w), ...
        'LabelOrientation','horizontal','HandleVisibility','off','FontSize',9);
end

set(gca,'XTick',n_pwr_plot);
xlabel('Number of power units');
ylabel('System mass [kg]');
title('Warlock system mass vs power-unit count');
subtitle(sprintf('Reference s/c %.0f kg; lines = mass fraction limits', m_sc_ref_w));
lgd = legend('Location','northwest'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 27: Power-scaling alpha vs P_e (family + benchmark ladder) ─────
% Specific mass alpha (kg/We) as a function of generated electrical power,
% spanning the literature benchmark ladder (RTG / RSG / reactor) and the
% Magdrive family architectures. Mass-band error bars on family points
% reflect head-mass uncertainty propagated through alpha_sys. All markers
% are labelled directly; legend shows marker classes only.
figure('Name','Specific mass vs power'); hold on; grid on; box on;

clr_warlock  = [0.90 0.45 0.00];   % orange — all Warlock configurations
clr_supermag = [0.65 0.05 0.10];   % dark red — SuperMagdrive

% ── Benchmark ladder ─────────────────────────────────────────────────────
b_alpha = sm.bench.alpha_kgWe;
b_P     = sm.bench.P_e_W;
b_class = sm.bench.class;
b_lab   = sm.bench.label;

class_def = {'RTG','RSG','Reactor'};
class_clr = [0.20 0.40 0.70;     % RTG blue
             0.10 0.60 0.30;     % RSG green
             0.85 0.30 0.10];    % Reactor red
class_mkr = {'o', 's', '^'};

for ci = 1:numel(class_def)
    sel = strcmp(b_class, class_def{ci});
    plot(b_P(sel), b_alpha(sel), class_mkr{ci}, ...
        'MarkerSize', 9, 'LineWidth', 1.2, ...
        'MarkerFaceColor', class_clr(ci,:) + (1-class_clr(ci,:))*0.6, ...
        'MarkerEdgeColor', class_clr(ci,:), ...
        'DisplayName', sprintf('System: %s', class_def{ci}));
end

% Per-benchmark labels — all bold.
b_layout = {'r','b','l','b','b','b','b','r','r','l','l','t'};
%            PA  PA+ ESA  MM  GPH RSG ASR KP1 KP10 NEPa NEPg JIMO
for k = 1:numel(b_alpha)
    [xoff, yoff, ha, va] = label_offset(b_layout{k});
    text(b_P(k) * xoff, b_alpha(k) * yoff, ['  ' b_lab{k} '  '], ...
        'FontSize', 8, 'FontWeight','bold', ...
        'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
        'Interpreter','none', 'Color', class_clr(strcmp(class_def, b_class{k}),:));
end

% RTG fit line removed (empirical 4-point fit; RTG+ sits off-trend for
% a physical reason and the line adds more confusion than insight).

% ── Family architectures ──────────────────────────────────────────────────
% All filled diamonds (no open markers — matches Fig 28 convention).
% Warlock orange, SuperMag dark red. No error bars on SuperMag.
% Warlock+RTG+ added at RTG+ power output.
fam_P   = [rtg.P_design_W, ...
           rtg_plus.P_design_W, ...
           NEP_W.power_rsg35.P_e_W,  NEP_W.power_rsg100.P_e_W, ...
           NEP_SM.power.P_e_W];
fam_a   = [sm.alpha.system_kgWe, ...
           (rogue.mass_kg + rtg_plus.mass_kg) / rtg_plus.P_design_W, ...
           NEP_W.unc.alpha_nom_kgWe(2), NEP_W.unc.alpha_nom_kgWe(3), ...
           NEP_SM.unc.alpha_nom_kgWe(5)];
fam_lo  = [sm.alpha.system_kgWe, NaN, NaN, NaN, NaN];
fam_hi  = [sm.alpha.system_kgWe, NaN, NaN, NaN, NaN];
fam_lbl = {'Rogue + RTG', 'Rogue/Warlock + RTG+', ...
           'Warlock + RSG-35', 'Warlock + RSG-100', ...
           'SuperMag + RSG-200'};
fam_clr = [fam_colors(1,:); [0.40 0.70 0.90]; ...
           clr_warlock; clr_warlock; ...
           clr_supermag];
fam_layout = {'t','l','t','b','r'};

for k = 1:numel(fam_P)
    if ~isnan(fam_lo(k))
        eb = errorbar(fam_P(k), fam_a(k), ...
            fam_a(k)-fam_lo(k), fam_hi(k)-fam_a(k), ...
            'd', 'MarkerSize', 9, 'LineWidth', 1.5, ...
            'Color', fam_clr(k,:), 'MarkerFaceColor', fam_clr(k,:), ...
            'MarkerEdgeColor', 'k', 'HandleVisibility','off');
        if isprop(eb,'CapSize'), eb.CapSize = 6; end
    else
        plot(fam_P(k), fam_a(k), 'd', 'MarkerSize', 9, 'LineWidth', 1.5, ...
            'Color', fam_clr(k,:), 'MarkerFaceColor', fam_clr(k,:), ...
            'MarkerEdgeColor', 'k', 'HandleVisibility','off');
    end
    [xoff, yoff, ha, va] = label_offset(fam_layout{k});
    text(fam_P(k) * xoff, fam_a(k) * yoff, ['  ' fam_lbl{k} '  '], ...
        'FontSize', 8, 'FontWeight','bold', ...
        'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
        'Color', fam_clr(k,:), 'Interpreter','none');
end

% ── NEXT-C / SPT-140 drawn before other comparators ──────────────────────
% Lines/markers faded; text labels full-strength (matches Fig 28).
% On this figure the trajectory is DIAGONAL: both P_e and alpha change with r.
% SPT-140 name label placed on the left side of its marker.
ep_classes_solar25 = { ...
%   name      m_ep_kg  P_BOL_W  I_total_Ns  clr_faded              clr_label              lbl_side
    'NEXT-C',  50,     7400,    17e6,       [0.78 0.70 0.82],      [0.50 0.30 0.65],      'r'; ...
    'SPT-140', 38,     4500,    10e6,       [0.68 0.78 0.70],      [0.30 0.55 0.40],      'l'  };
au_pts25 = [1, 10];
au_lbl25 = {'1 AU', '10 AU'};
arr_kgkW_1AU_25 = 12;
for c = 1:size(ep_classes_solar25,1)
    nm        = ep_classes_solar25{c,1}; m_ep      = ep_classes_solar25{c,2};
    P_BOL     = ep_classes_solar25{c,3}; clr       = ep_classes_solar25{c,5};
    clr_label = ep_classes_solar25{c,6}; lbl_side  = ep_classes_solar25{c,7};
    P_au  = P_BOL ./ (au_pts25.^2);
    m_arr = arr_kgkW_1AU_25 * (P_BOL/1000);
    a_au  = (m_ep + m_arr) ./ P_au;
    plot(P_au, a_au, '--', 'Color', clr, 'LineWidth', 0.9, 'HandleVisibility','off');
    for a = 1:numel(au_pts25)
        plot(P_au(a), a_au(a), '^', 'MarkerSize', 7, 'LineWidth', 0.8, ...
            'MarkerFaceColor', clr + (1-clr)*0.4, 'MarkerEdgeColor', clr, ...
            'HandleVisibility','off');
        text(P_au(a)*1.08, a_au(a)*0.85, au_lbl25{a}, 'FontSize', 7.5, ...
            'FontWeight','bold', 'Color', clr_label, 'HorizontalAlignment','left');
    end
    if strcmp(lbl_side, 'l')
        text(P_au(1)*0.85, a_au(1), nm, 'FontSize', 8, 'FontWeight','bold', ...
            'Color', clr_label, 'VerticalAlignment','middle', 'HorizontalAlignment','right');
    else
        text(P_au(1)*1.15, a_au(1), nm, 'FontSize', 8, 'FontWeight','bold', ...
            'Color', clr_label, 'VerticalAlignment','middle', 'HorizontalAlignment','left');
    end
end

% ── Additional EP comparators ─────────────────────────────────────────────
% VASIMR and JPL Li-MPD use circles ('o') to match Fig 26.
ep_extra25 = { ...
%   name                   P_e_W    m_thr_kg  solar_dep  layout
    'EO-1 PPT',            5,       5.0,      true,      'l';    ...
    'Busek BET-MAX',       12,      0.80,     true,      'l';    ...
    ['ThrustMe NPT30-I2 / ' ...
    'ENPULSION NANO R3'],  40,      1.42,     true,      'l';    ...
    'BIT-3 (Busek)',       75,      1.40,     true,      'l';    ...
    'Xantus (BSS)',        80,      1.40,     true,      'b';    ...
    'Enpulsion MICRO R3',  100,     3.90,     true,      'r';    ...
    'Enpulsion NEXUS',     100,     4.90,     true,      't';    ...
    'JPL Li-MPD',          120e3,   100,      false,     'l';    ...
    'VASIMR VX-200',       200e3,   250,      false,     'b'     };
arr_kgkWe_25     = 10; 
reactor_kgkWe_25 = 20;
clr_sdep_25  = [0.60 0.20 0.60];
clr_sindp_25 = [0.15 0.55 0.75];
for k = 1:size(ep_extra25,1)
    nm_e  = ep_extra25{k,1}; P_e   = ep_extra25{k,2};
    m_thr = ep_extra25{k,3}; sdep  = ep_extra25{k,4};
    lay_e = ep_extra25{k,5};
    if sdep
        m_ps  = arr_kgkWe_25 * (P_e/1000);
        clr_e = clr_sdep_25;
    else
        m_ps  = reactor_kgkWe_25 * (P_e/1000);
        clr_e = clr_sindp_25;
    end
    a_e = (m_thr + m_ps) / P_e;
    if sdep
        plot(P_e, a_e, '^', 'MarkerSize', 9, 'LineWidth', 1, ...
            'MarkerFaceColor', 'w', 'MarkerEdgeColor', clr_e, ...
            'HandleVisibility','off');
    else
        plot(P_e, a_e, 'o', 'MarkerSize', 9, 'LineWidth', 1.2, ...
            'MarkerFaceColor', clr_e, 'MarkerEdgeColor', 'k', ...
            'HandleVisibility','off');
    end
    [xoff, yoff, ha, va] = label_offset(lay_e);
    text(P_e * xoff, a_e * yoff, ['  ' nm_e '  '], ...
        'FontSize', 8, 'FontWeight','bold', ...
        'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
        'Color', clr_e, 'Interpreter','none');
end

% ── Flight SEP missions ───────────────────────────────────────────────────
mis_lbl = {'Dawn EOL @3 AU','DS1 EOL @1.4 AU','Psyche EOL @3 AU','DART @1 AU'};
mis_P   = [1300, 2000, 2300, 6400];
mis_a   = [0.192, 0.035, 0.109, 0.011];
mis_lay = {'r','l','b','l'};
mis_clr = [0.95 0.65 0.10];
for k = 1:numel(mis_P)
    plot(mis_P(k), mis_a(k), 'p', 'MarkerSize', 10, 'LineWidth', 1.2, ...
        'MarkerFaceColor', mis_clr + (1-mis_clr)*0.6, ...
        'MarkerEdgeColor', mis_clr, 'HandleVisibility','off');
    [xoff, yoff, ha, va] = label_offset(mis_lay{k});
    text(mis_P(k) * xoff, mis_a(k) * yoff, ['  ' mis_lbl{k} '  '], ...
        'FontSize', 8, 'FontWeight','bold', ...
        'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
        'Color', mis_clr, 'Interpreter','none');
end

% ── Legend ────────────────────────────────────────────────────────────────
plot(NaN, NaN, 'kd', 'MarkerSize', 8, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.5 0.5 0.5], 'DisplayName', 'Family: single unit');
plot(NaN, NaN, '^--', 'MarkerSize', 8, 'LineWidth', 0.9, ...
    'Color', [0.75 0.75 0.75], 'MarkerFaceColor', [0.85 0.85 0.85], ...
    'MarkerEdgeColor', [0.75 0.75 0.75], ...
    'DisplayName', 'Solar EP @ 1 & 10 AU');
plot(NaN, NaN, '^', 'MarkerSize', 8, 'LineWidth', 1, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', clr_sdep_25, ...
    'DisplayName', 'Solar-dependent EP (1 AU only)');
plot(NaN, NaN, 'o', 'MarkerSize', 8, 'LineWidth', 1.2, ...
    'MarkerFaceColor', clr_sindp_25, 'MarkerEdgeColor', 'k', ...
    'DisplayName', 'Solar-independent EP (reactor-class)');
plot(NaN, NaN, 'p', 'MarkerSize', 8, 'LineWidth', 1.2, ...
    'MarkerFaceColor', mis_clr + (1-mis_clr)*0.6, 'MarkerEdgeColor', mis_clr, ...
    'DisplayName', 'SEP flight missions');

set(gca,'XScale','log','YScale','log');
xlim([1 5e5]); ylim([1e-3 5]);
xlabel('Generated electrical power P_e [We]');
ylabel('Specific mass \alpha [kg/We]');
yticklabels({'0.001','0.01','0.1','1'});
title('Specific-mass scaling: family vs benchmark missions and systems');
lgd = legend('Location','southwest'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG 28: Specific mass vs total impulse capability ─────────────────
% Mission-relevant framing: alpha_sys (kg/We) on y, total impulse (Ns) on x.
% Family architectures use pulse-budget binding: I_total = min(I_bit*N, spec).
% EP class comparators (NEXT-C, SPT-140) shown at 1 AU and 10 AU — vertical
% trajectory because qualified I_total is fixed but alpha rises as 1/r^2.
% Flight SEP missions (Dawn, DS1, Psyche, DART) shown at EOL/at-design-distance
% values mission planners actually size to.
%
% Colour conventions:
%   Rogue configs  : fam_colors(1,:) / fam_colors(2,:) / light blue (RTG+)
%   Warlock configs: orange [0.90 0.45 0.00] (all power sources)
%   SuperMag       : dark red [0.65 0.05 0.10]
figure('Name','Specific mass vs I_total'); hold on; grid on; box on;

clr_warlock = [0.90 0.45 0.00];   % orange — all Warlock configurations
clr_supermag = [0.65 0.05 0.10];  % dark red — SuperMagdrive

% ── NEXT-C / SPT-140 drawn first so they sit behind family markers ──────
% Lines/markers use faded colours; text labels use full-strength colours.
ep_classes_solar26 = { ...
%   name      m_ep_kg  P_BOL_W  I_qual_Ns   clr_faded              xshift  clr_label
    'NEXT-C',  38,     7400,    34.3e6,    [0.78 0.70 0.82],       1.18,  [0.50 0.30 0.65]; ...
    'SPT-140', 30,     4500,    9.0e6,     [0.68 0.78 0.70],       0.85,  [0.30 0.55 0.40]  };
au_pts26 = [1, 10];
au_lbl26 = {'1 AU', '10 AU'};
arr_kgkW_1AU_26 = 13;
for c = 1:size(ep_classes_solar26,1)
    nm       = ep_classes_solar26{c,1}; m_ep  = ep_classes_solar26{c,2};
    P_BOL    = ep_classes_solar26{c,3}; I_qual = ep_classes_solar26{c,4};
    clr      = ep_classes_solar26{c,5}; xshift = ep_classes_solar26{c,6};
    clr_label = ep_classes_solar26{c,7};
    P_au  = P_BOL ./ (au_pts26.^2);
    m_arr = arr_kgkW_1AU_26 * (P_BOL/1000);
    a_au  = (m_ep + m_arr) ./ P_au;
    % Faded dashed line — drawn before family markers so it sits behind.
    plot(I_qual * xshift * ones(size(au_pts26)), a_au, '--', 'Color', clr, ...
        'LineWidth', 0.9, 'HandleVisibility','off');
    for a = 1:numel(au_pts26)
        plot(I_qual * xshift, a_au(a), '^', 'MarkerSize', 9, 'LineWidth', 0.8, ...
            'MarkerFaceColor', clr + (1-clr)*0.4, 'MarkerEdgeColor', clr, ...
            'HandleVisibility','off');
        text(I_qual * xshift * 1.12, a_au(a), au_lbl26{a}, 'FontSize', 7.5, ...
            'FontWeight','bold', 'Color', clr_label, 'VerticalAlignment','middle');
    end
    text(I_qual * xshift, a_au(end)*1.25, nm, 'FontSize', 8.5, 'FontWeight','bold', ...
        'Color', clr_label, 'HorizontalAlignment','center');
end

% ── Family single-unit points ─────────────────────────────────────────────
% 7 configurations. All use filled diamonds.
rtg_plus_alpha_sys_warlock   = (NEP_W.cfg.m_thruster_kg + rtg_plus.mass_kg) / rtg_plus.P_design_W;
rtg_plus_alpha_sys_rogue_pub = (NEP_RP.m_thruster_kg    + rtg_plus.mass_kg) / rtg_plus.P_design_W;

famI_P   = [120, ...
            NEP_RP.I_total_Ns, NEP_RP.I_total_Ns, ...
            NEP_W.I_total_Ns,  NEP_W.I_total_Ns,  NEP_W.I_total_Ns, ...
            NEP_SM.I_total_Ns];
famI_a   = [sm.alpha.system_kgWe, ...
            NEP_RP.mass.alpha_sys, rtg_plus_alpha_sys_rogue_pub, ...
            NEP_W.unc.alpha_nom_kgWe(1), rtg_plus_alpha_sys_warlock, NEP_W.unc.alpha_nom_kgWe(2), ...
            NEP_SM.unc.alpha_nom_kgWe(5)];
famI_lbl = {'Rogue + RTG (demo)', ...
            'Rogue + RTG (public)', 'Rogue + RTG+ (public)', ...
            'Warlock + RTG', 'Warlock + RTG+', 'Warlock + RSG-35', ...
            'SuperMag + RSG-200'};
famI_clr = [fam_colors(1,:); ...
            fam_colors(2,:); [0.40 0.70 0.90]; ...
            clr_warlock;     clr_warlock;       clr_warlock; ...
            clr_supermag];
famI_layout = {'r','t','b','t','b','t','r'};

for k = 1:numel(famI_P)
    plot(famI_P(k), famI_a(k), 'd', 'MarkerSize', 9, 'LineWidth', 1.5, ...
        'Color', famI_clr(k,:), 'MarkerFaceColor', famI_clr(k,:), ...
        'MarkerEdgeColor', 'k', 'HandleVisibility','off');
    [xoff, yoff, ha, va] = label_offset(famI_layout{k});
    text(famI_P(k) * xoff, famI_a(k) * yoff, ['  ' famI_lbl{k} '  '], ...
        'FontSize', 8.5, 'FontWeight','bold', ...
        'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
        'Color', famI_clr(k,:), 'Interpreter','none');
end

% ── Stacked configurations ────────────────────────────────────────────────
% family_idx maps to famI arrays: 2=Rogue+RTG(pub), 3=Rogue+RTG+(pub),
%                                 4=Warlock+RTG,    5=Warlock+RTG+.
stacks = { ...
    2, 4, 1, '4x Rogue + RTG (public)',  't'; ...
    3, 4, 1, '4x Rogue + RTG+',          'b'; ...
    4, 4, 1, '4x Warlock + RTG',         't'; ...
    5, 4, 1, '4x Warlock + RTG+',        'b'  };

stk_thr_m = [rogue.mass_kg,           rogue.mass_kg,          rogue.mass_kg, ...
             NEP_W.cfg.m_thruster_kg,  NEP_W.cfg.m_thruster_kg, NaN, ...
             NEP_SM.cfg.m_thruster_kg];
stk_pwr_m = [rtg.mass_kg,             rtg.mass_kg,             rtg_plus.mass_kg, ...
             rtg.mass_kg,              rtg_plus.mass_kg,        NaN, ...
             NEP_SM.power.m_kg];
stk_pwr_P = [rtg.P_design_W,          rtg.P_design_W,          rtg_plus.P_design_W, ...
             rtg.P_design_W,           rtg_plus.P_design_W,     NaN, ...
             NEP_SM.power.P_e_W];
stk_I_thr = [rogue.I_bit_Ns * rogue.n_pulses_ambition, ...
             NEP_RP.I_total_Ns, NEP_RP.I_total_Ns, ...
             NEP_W.I_total_Ns,  NEP_W.I_total_Ns, ...
             NaN, NEP_SM.I_total_Ns];

for s = 1:size(stacks,1)
    fi  = stacks{s,1}; nR = stacks{s,2}; nT = stacks{s,3};
    lbl = stacks{s,4}; lay = stacks{s,5};
    I_total = nR * stk_I_thr(fi);
    m_sys   = nR * stk_thr_m(fi) + nT * stk_pwr_m(fi);
    a_sys   = m_sys / (nT * stk_pwr_P(fi));
    clr     = famI_clr(fi,:);
    plot(I_total, a_sys, 's', 'MarkerSize', 9, 'LineWidth', 1.5, ...
        'Color', clr, 'MarkerFaceColor', clr, ...
        'MarkerEdgeColor', 'k', 'HandleVisibility','off');
    [xoff, yoff, ha, va] = label_offset(lay);
    text(I_total * xoff, a_sys * yoff, ['  ' lbl '  '], ...
        'FontSize', 8.5, 'FontWeight','bold', ...
        'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
        'Color', clr, 'Interpreter','none');
end

% ── Additional EP comparator points ──────────────────────────────────────
% Sources:
%   ENPULSION NANO R3  : Enpulsion/Satsearch datasheet; 40 W nom, 1.42 kg wet, >5 kNs
%   ThrustMe NPT30-I2  : thrustme.fr product page; Rafalskyi et al. 2021; 40 W, 1.42 kg, 5.5 kNs
%   BIT-3 (Busek)      : Busek datasheet; 56-75 W, 1.40 kg; ~7.5 kNs (mission analysis)
%   Busek BET-MAX      : Busek datasheet v1.0 Aug 2021; 4x BET-300-P; 12 W sys; 0.8 kg BOL; 360 Ns Config A dem.
%   Enpulsion MICRO R3 : Enpulsion website; 90-100 W nom, 3.9 kg wet, 26 kNs nominal
%   Enpulsion NEXUS    : Enpulsion product page; 50-150 W (nom. 100 W); 4.9 kg wet; 30 kNs
%   Xantus (BSS)       : Benchmark datasheet Apr 2026; 80 W, 1.4 kg, 2 kNs demonstrated
%   JPL Li-MPD         : NASA 2024-2025; 120 kW; 100 kg thr+PPU+feed + 2400 kg CBC
%   VASIMR VX-200      : Ad Astra; 200 kW; 250 kg thr + 4000 kg CBC; I_total unqualified
ep_extra26 = { ...
%   name                  I_total_Ns  m_thr_kg  P_e_W    solar_dep  layout
    'EO-1 PPT',           600,        5.0,      5,       true,      'b';     ...
    'Busek BET-MAX',      360,        0.80,     12,      true,      'r';     ...
    'Xantus (BSS)',       2000,       1.40,     80,      true,      'b';     ...
    'ENPULSION NANO R3',  5000,       1.42,     40,      true,      'l';     ...
    'ThrustMe NPT30-I2',  5500,       1.42,     40,      true,      'r';     ...
    'BIT-3 (Busek)',      7500,       1.40,     75,      true,      'r';     ...
    'Enpulsion MICRO R3', 26000,      3.90,     100,     true,      'r';     ...
    'Enpulsion NEXUS',    30000,      4.90,     100,     true,      't';     ...
    'JPL Li-MPD',         NaN,        100,      120e3,   false,     'r';     ...
    'VASIMR VX-200',      NaN,        250,      200e3,   false,     'r'      };
arr_kgkWe_26     = 10;
reactor_kgkWe_26 = 20;
clr_sdep_26  = [0.60 0.20 0.60];
clr_sindp_26 = [0.15 0.55 0.75];
for k = 1:size(ep_extra26,1)
    nm_e  = ep_extra26{k,1}; I_e   = ep_extra26{k,2};
    m_thr = ep_extra26{k,3}; P_e   = ep_extra26{k,4};
    sdep  = ep_extra26{k,5}; lay_e = ep_extra26{k,6};
    if sdep
        m_ps  = arr_kgkWe_26 * (P_e/1000);
        clr_e = clr_sdep_26;
    else
        m_ps  = reactor_kgkWe_26 * (P_e/1000);
        clr_e = clr_sindp_26;
    end
    a_e = (m_thr + m_ps) / P_e;
    if ~isnan(I_e)
        if sdep
            plot(I_e, a_e, '^', 'MarkerSize', 9, 'LineWidth', 1, ...
                'MarkerFaceColor', 'w', 'MarkerEdgeColor', clr_e, ...
                'HandleVisibility','off');
        else
            plot(I_e, a_e, 's', 'MarkerSize', 9, 'LineWidth', 1.2, ...
                'MarkerFaceColor', clr_e, 'MarkerEdgeColor', 'k', ...
                'HandleVisibility','off');
        end
        [xoff, yoff, ha, va] = label_offset(lay_e);
        text(I_e * xoff, a_e * yoff, ['  ' nm_e '  '], ...
            'FontSize', 8, 'FontWeight','bold', ...
            'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
            'Color', clr_e, 'Interpreter','none');
    else
        x_nan_Ns = 3e7;
        if strcmp(nm_e, 'JPL Li-MPD')
            a_plot = a_e * 1.18; lay_nan = 't';
        else
            a_plot = a_e * 0.85; lay_nan = 'b';
        end
        plot(x_nan_Ns, a_plot, 'o', 'MarkerSize', 9, 'LineWidth', 1.2, ...
            'MarkerFaceColor', clr_e, 'MarkerEdgeColor', 'k', ...
            'HandleVisibility','off');
        [xoff, yoff, ha, va] = label_offset(lay_nan);
        text(x_nan_Ns * xoff, a_plot * yoff, ['> ' nm_e], ...
            'FontSize', 8, 'FontWeight','bold', ...
            'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
            'Color', clr_e, 'Interpreter','none');
    end
end

% ── Flight SEP mission comparators ───────────────────────────────────────
sep_I      = [12.9e6, 2.5e6, 19.2e6, 2.45e6];
sep_alpha  = [0.192, 0.035, 0.154, 0.023];
sep_lbl    = {'Dawn EOL @3 AU', 'DS1 EOL @1.4 AU', 'Psyche EOL @3 AU', 'DART @1 AU'};
sep_layout = {'t','t','b','b'};
sep_clr    = [0.95 0.65 0.10];
for k = 1:numel(sep_I)
    plot(sep_I(k), sep_alpha(k), 'p', 'MarkerSize', 9, 'LineWidth', 1.2, ...
        'MarkerFaceColor', sep_clr + (1-sep_clr)*0.6, ...
        'MarkerEdgeColor', sep_clr, 'HandleVisibility','off');
    [xoff, yoff, ha, va] = label_offset(sep_layout{k});
    text(sep_I(k) * xoff, sep_alpha(k) * yoff, ['  ' sep_lbl{k} '  '], ...
        'FontSize', 9, 'FontWeight','bold', ...
        'HorizontalAlignment', ha, 'VerticalAlignment', va, ...
        'Color', sep_clr, 'Interpreter','none');
end

% ── Legend ────────────────────────────────────────────────────────────────
plot(NaN, NaN, 'kd', 'MarkerSize', 9, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.5 0.5 0.5], 'DisplayName', 'Family: single unit');
plot(NaN, NaN, 'ks', 'MarkerSize', 11, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.5 0.5 0.5], 'DisplayName', 'Family: stacked configuration');
plot(NaN, NaN, '^--', 'MarkerSize', 9, 'LineWidth', 0.9, ...
    'Color', [0.75 0.75 0.75], 'MarkerFaceColor', [0.85 0.85 0.85], ...
    'MarkerEdgeColor', [0.75 0.75 0.75], ...
    'DisplayName', 'Solar EP @ 1 & 10 AU (1/r^2)');
plot(NaN, NaN, '^', 'MarkerSize', 9, 'LineWidth', 1, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', clr_sdep_26, ...
    'DisplayName', 'Solar-dependent EP (1 AU only)');
plot(NaN, NaN, 's', 'MarkerSize', 9, 'LineWidth', 1.2, ...
    'MarkerFaceColor', clr_sindp_26, 'MarkerEdgeColor', 'k', ...
    'DisplayName', 'Solar-independent EP (reactor-class)');
plot(NaN, NaN, 'p', 'MarkerSize', 9, 'LineWidth', 1.2, ...
    'MarkerFaceColor', sep_clr + (1-sep_clr)*0.6, 'MarkerEdgeColor', sep_clr, ...
    'DisplayName', 'SEP flight missions');

set(gca,'XScale','log','YScale','log');
xlim([50 1e8]); ylim([0.01 10]);
xlabel('Total impulse capability I_{total} [Ns]');
ylabel('Specific mass \alpha [kg/We]');
yticklabels({'0.01','0.1','1','10'});
title('Specific mass vs total impulse capability for Magdrive + PA family and selected comparators');
lgd = legend('Location','southwest'); style_legend(lgd); ax(); fig(); hold off;

end   % end of fam_ok block

%% ── FIG 29: Closure-margin heatmap (requires family struct) ───────────
% Per-(config, profile) closure margin at 10M pulses. Margin = (I_del - I_req)/I_req.
% Log-coloured; NaN cells (profile does not close) shown in grey.
% Data source: family.feasibility.margin_grid built from ep (35 profiles).
if ~exist('family','var') || ~isfield(family,'feasibility') || ~family.feasibility.available
    fprintf('  [Fig 29 skipped: run Extended_Profiles + Family_Compare first]\n');
else
    margin   = family.feasibility.margin_grid;
    cfg_lbls = family.feasibility.config_labels;
    n_cfg_m  = numel(cfg_lbls);
    n_prof_m = size(margin, 2);

    % Profile labels from EXT struct; trim to 22 chars for readability at 35 profiles.
    if exist('EXT','var') && isfield(EXT,'profiles')
        raw_lbl    = {EXT.profiles.label};
        prof_lbl_m = cellfun(@(s) s(1:min(numel(s),22)), raw_lbl, 'UniformOutput', false);
    else
        prof_lbl_m = arrayfun(@(i) sprintf('P%d', i), 1:n_prof_m, 'UniformOutput', false);
    end

    % Log10 transform; floor at log10(0.01) for colour scale.
    M_log = log10(max(margin, 0.01));

    % Scale figure width and font size to profile count.
    fig_w  = max(900, n_prof_m * 28);
    tick_fs = max(6, 9 - floor(n_prof_m / 10));
    ovl_fs  = max(5, 7 - floor(n_prof_m / 12));

    figure('Name','Closure-margin heatmap');
    imagesc(M_log, 'AlphaData', ~isnan(M_log));
    set(gca, 'Color', [0.85 0.85 0.85]);
    colormap(parula);
    cb = colorbar;
    cb.Label.String = 'log_{10}(closure margin)  [0 = parity, 1 = 10x headroom]';
    cb.Label.FontSize = 9;

    set(gca, 'YTick', 1:n_cfg_m, 'YTickLabel', cfg_lbls, ...
             'XTick', 1:n_prof_m, 'XTickLabel', prof_lbl_m, ...
             'XTickLabelRotation', 65, 'TickLabelInterpreter','none', ...
             'FontSize', tick_fs, 'YDir', 'normal');
    xlabel('Mission profile');
    ylabel('Configuration');
    title('Closure margin at 10M pulses');
    subtitle('Grey = profile does not close; brighter = more headroom');

    % Numeric overlay for closed cells.
    for r = 1:n_cfg_m
        for cc = 1:n_prof_m
            v = margin(r,cc);
            if isnan(v), continue; end
            if v < 1,        s = sprintf('%.2f',v);
            elseif v < 10,   s = sprintf('%.1f',v);
            elseif v < 1000, s = sprintf('%.0f', v);
            else,            s = sprintf('%.0e', v); end
            clr = text_colour_for_value(M_log(r,cc), M_log(~isnan(M_log)), false);
            text(cc, r, s, 'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', 'FontSize', ovl_fs, 'Color', clr);
        end
    end
    ax(); fig();
end

%% ── LOCAL FUNCTIONS ────────────────────────────────────────────────────

function clr = text_colour_for_value(v, data, invert)
% White text on dark cells, black on light. Works for parula and flipud(parula).
% invert=true flips the test for "less is better" colormaps.
    rng = max(max(data(:)) - min(data(:)), eps);
    nrm = (v - min(data(:))) / rng;
    if invert, nrm = 1 - nrm; end
    if nrm < 0.55, clr = [1 1 1]; else, clr = [0 0 0]; end
end

function [xoff, yoff, ha, va] = label_offset(code)
% Compact label-placement helper for log-log scatter plots. Returns
% multiplicative x and y offsets and text alignment settings, given a
% one-character placement code:
%   'r' = right of marker, baseline aligned (default)
%   'l' = left of marker
%   't' = above marker
%   'b' = below marker
    switch code
        case 'r', xoff = 1.10; yoff = 1.00; ha = 'left';   va = 'middle';
        case 'l', xoff = 0.91; yoff = 1.00; ha = 'right';  va = 'middle';
        case 't', xoff = 1.00; yoff = 1.18; ha = 'center'; va = 'bottom';
        case 'b', xoff = 1.00; yoff = 0.85; ha = 'center'; va = 'top';
        otherwise, xoff = 1.10; yoff = 1.00; ha = 'left'; va = 'middle';
    end
end

function dv = local_tsiol(I_bit, n_pulses, m_sc, m_sys, Isp, g0)
% Exact-Tsiolkovsky pulse-life dV (self-contained copy for Plots.m).
% Mirrors delta_v_lifetime() in Model.m; NaN if mass-infeasible.
    if m_sc <= m_sys, dv = NaN; return; end
    m_p = I_bit * n_pulses / (Isp * g0);
    if m_p >= m_sc - m_sys, dv = NaN; return; end
    dv = Isp * g0 * log(m_sc / (m_sc - m_p));
end

function out = ternary(cond, a, b)
% Inline conditional for compact console pass/fail labels.
    if cond, out = a; else, out = b; end
end