%% =========================================================================
%% MicroNEP_Thermal_Plots.m — Thermal Analysis Figures
%% =========================================================================
% Thermal figures for the RTG-Rogue coupling interface. All Rogue values are
% from Exotrail FEM (10 s burst at 100 Hz / 4 J/pulse); extended bursts and
% RTG contact are uncharacterised, so all derived quantities are first-order.
%
% Burst duration scaling: peak internal ΔT values are scaled linearly from
% the 10 s FEM reference using the near-adiabatic assumption (ΔT ∝ P×t).
% Set cfg.t_burst_s in MicroNEP_Params.m to switch between durations.
% Time constants (τ) are assumed invariant with burst duration.
%
% Requires MicroNEP_Model.m to have been run first.
%
% Figures:
%   T1  RTG fin equilibrium temperature vs radiating area
%   T2  Rogue internal heat budget (burst dissipation, per node)
%   T3  Post-burst cooldown (single cycle, scaled burst duration)
%   T4  Multi-cycle internal temperatures (scaled burst duration)

if ~exist('NEP','var'), error('Run MicroNEP_Model.m first.'); end

rogue = NEP.params.rogue;   rtg   = NEP.params.rtg;
cfg   = NEP.params.cfg;     th_r  = NEP.th_rogue;
mppt  = NEP.params.mppt;    sigma = NEP.const.sigma;

ax           = @() set(gca,'FontName','Arial','FontSize',11,'LineWidth',1,'Box','on','Layer','top');
fig          = @() set(gcf,'Color','w');
style_legend = @(h) set(h,'Box','on','FontSize',10);
C            = lines(8);

%% ── BURST DURATION SCALING ──────────────────────────────────────────────
% FEM data (dT_X_pk_C) is calibrated for a 10 s burst at 100 Hz / 4 J/pulse.
% Near-adiabatic scaling: ΔT_peak ∝ burst duration (linear, heat ∝ P×t).
% Adjust cfg.t_burst_s in MicroNEP_Params.m to model different durations.
% Time constants (τ) depend on the thermal network topology, not burst energy,
% and are held fixed. If Exotrail provides a 20 s FEM run, update dT_X_pk_C
% directly in MicroNEP_Params.m and remove this scaling block entirely.
t_FEM_s   = 10;                         % FEM reference burst duration [s]
t_burst_s = cfg.t_burst_s;             % active burst duration (from Params)
scale     = t_burst_s / t_FEM_s;       % linear scaling factor

dT_motor_pk = rogue.th.dT_motor_pk_C * scale;
dT_PPS_pk   = rogue.th.dT_PPS_pk_C   * scale;
dT_HVG_pk   = rogue.th.dT_HVG_pk_C   * scale;
dT_hw_pk    = rogue.th.dT_hwpeak_C   * scale;

% Warn if extrapolating well beyond FEM range.
if scale > 2.5
    warning('Burst scaling factor %.1fx is far beyond FEM calibration (10 s). Near-adiabatic assumption may not hold at this duration.', scale);
end

% Export for MicroNEP_Summary.m section 12 (struct interface; avoids
% Summary sniffing loose workspace variables).
th_scaled.t_burst_s    = t_burst_s;
th_scaled.scale        = scale;
th_scaled.dT_motor_pk_C = dT_motor_pk;
th_scaled.dT_PPS_pk_C   = dT_PPS_pk;
th_scaled.dT_HVG_pk_C   = dT_HVG_pk;
th_scaled.dT_hw_pk_C    = dT_hw_pk;

fprintf('Thermal Plots: burst %.0f s (FEM ref 10 s, scale %.2fx)\n', t_burst_s, scale);
fprintf('  Motor peak dT : %.1f degC\n', dT_motor_pk);
fprintf('  PPS   peak dT : %.1f degC\n', dT_PPS_pk);
fprintf('  HVG   peak dT : %.1f degC\n', dT_HVG_pk);

%% ── FIG T1: RTG fin equilibrium temperature vs radiating area ──────────
figure; hold on; grid on;
plot(NEP.th_rtg.A_sweep_m2, NEP.th_rtg.T_sweep_C, '-', ...
    'LineWidth', 2, 'Color', C(1,:), 'DisplayName', 'Equilibrium T (design 10 We)');

plot(rtg.A_radiate_m2, NEP.th_rtg.T_eq_C, 'o', ...
    'MarkerSize', 10, 'MarkerFaceColor', C(1,:), 'MarkerEdgeColor','k', ...
    'DisplayName', sprintf('Design: %.1f^{\\circ}C  (%.0f We)', NEP.th_rtg.T_eq_C, rtg.P_design_W));

plot(rtg.A_radiate_m2, NEP.th_rtg.T_eq_lab_C, 's', ...
    'MarkerSize', 10, 'MarkerFaceColor', C(2,:), 'MarkerEdgeColor','k', ...
    'DisplayName', sprintf('Lab-min: %.1f^{\\circ}C  (%.1f We)', ...
    NEP.th_rtg.T_eq_lab_C, rtg.P_lab_min_W));

yline(-30, '--', 'Color',[0.5 0.5 0.5], 'LineWidth',1, 'HandleVisibility','off');
yline(-70, ':',  'Color',[0.5 0.5 0.5], 'LineWidth',1, 'HandleVisibility','off');
text(0.02, -28, 'Viton -30^{\circ}C (ground only)', 'FontSize',9,'Color',[0.5 0.5 0.5]);
text(0.02, -68, 'Fin adhesive -70^{\circ}C',        'FontSize',9,'Color',[0.5 0.5 0.5]);

xline(rtg.A_radiate_m2, ':k', sprintf('Current fin %.3f m^2', rtg.A_radiate_m2), ...
    'LabelOrientation','horizontal','HandleVisibility','off');

xlabel('Radiating area [m^2]');
ylabel('Fin equilibrium temperature [^{\circ}C]');
title('RTG fin equilibrium temperature');
subtitle(sprintf('Stefan-Boltzmann balance, deep space, housing %d^{\\circ}C', rtg.T_housing_C));
lgd = legend('Location','northeast'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG T2: Rogue internal heat budget ─────────────────────────────────
% Note: heat budget pie and capacitance bars use FEM reference values (10 s)
% directly — these are measured quantities, not scaled estimates.
P_other = rogue.th.P_internal_W - rogue.th.P_PPS_W - rogue.th.P_motor_W - rogue.th.P_HVG_W;
nodes   = {'PPS','Motor','HVG'};
dT_pk   = [rogue.th.dT_PPS_pk_C, rogue.th.dT_motor_pk_C, rogue.th.dT_HVG_pk_C];
C_vals  = [th_r.C_PPS_JK, th_r.C_motor_JK, th_r.C_HVG_JK];
bar_col = [C(2,:); C(1,:); C(3,:)];

figure;
subplot(1,3,1);
pie([rogue.th.P_PPS_W, rogue.th.P_motor_W, rogue.th.P_HVG_W, P_other], ...
    {'PPS','Motor','HVG','Other (TCU etc.)'});
title(sprintf('Power dissipation\n%.1f W total', rogue.th.P_internal_W), 'FontSize', 11);

subplot(1,3,2); hold on; grid on;
b = bar(1:3, dT_pk, 0.55, 'FaceColor','flat');
for ni = 1:3, b.CData(ni,:) = bar_col(ni,:); end
yline(rogue.T_op_C(2) - rogue.th.T_ambient_C, '--r', ...
    sprintf('Op limit \\DeltaT = %.0f^{\\circ}C', rogue.T_op_C(2) - rogue.th.T_ambient_C), ...
    'LabelOrientation','horizontal','HandleVisibility','off');
set(gca,'XTick',1:3,'XTickLabel',nodes);
ylabel('\DeltaT_{peak} [^{\circ}C]'); title('Peak \DeltaT per node (10 s FEM)'); ax();

subplot(1,3,3); hold on; grid on;
b2 = bar(1:3, C_vals, 0.55, 'FaceColor','flat');
for ni = 1:3, b2.CData(ni,:) = bar_col(ni,:); end
set(gca,'XTick',1:3,'XTickLabel',nodes);
ylabel('Thermal capacitance [J/K]'); title('Thermal capacitance per node'); ax();

sgtitle(sprintf('Rogue internal heat budget (10 s FEM ref: %.0f Hz, %.1f J/pulse)', ...
    rogue.f_Hz, rogue.E_per_pulse_J), 'FontSize', 12, 'FontWeight', 'bold');
fig();

%% ── FIG T3: Post-burst cooldown (single cycle) ────────────────────────
% Peak ΔT values are scaled from 10 s FEM by (t_burst_s / 10).
% Time constants are invariant (thermal network topology, not burst energy).
t_cool = 0:1:1500;

T_motor = dT_motor_pk * exp(-t_cool / rogue.th.tau_motor_s);
T_PPS   = dT_PPS_pk   * exp(-t_cool / rogue.th.tau_PPS_fast_s);
T_HVG   = dT_HVG_pk   * exp(-t_cool / rogue.th.tau_HVG_fast_s);
T_hw    = dT_hw_pk    * exp(-t_cool / rogue.th.tau_hw_max_s);

t_recharge = rogue.E_store_J / (rtg.P_design_W * mppt.eta - rtg.P_parasitic_W);

% Motor cooldown to <1 degC: t = -tau * ln(1 / dT_peak)
t_to_1C_s = -rogue.th.tau_motor_s * log(1.0 / dT_motor_pk);
margin_s   = t_recharge - t_to_1C_s;

figure; hold on; grid on;
plot(t_cool/60, T_motor, '-',  'LineWidth',2.0, 'Color',C(1,:), ...
    'DisplayName', sprintf('Motor (\\tau = %.0f s)', rogue.th.tau_motor_s));
plot(t_cool/60, T_PPS,   '--', 'LineWidth',1.8, 'Color',C(2,:), ...
    'DisplayName', sprintf('PPS (\\tau = %.0f s)', rogue.th.tau_PPS_fast_s));
plot(t_cool/60, T_HVG,   ':',  'LineWidth',1.8, 'Color',C(3,:), ...
    'DisplayName', sprintf('HVG (\\tau = %.0f s)', rogue.th.tau_HVG_fast_s));
plot(t_cool/60, T_hw,    '-.', 'LineWidth',1.5, 'Color',C(4,:), ...
    'DisplayName', sprintf('Hot wall (\\tau = %.0f s)', rogue.th.tau_hw_max_s));

xline(t_recharge/60, '--k', sprintf('Recharge end %.0f min', t_recharge/60), ...
    'LabelOrientation','horizontal','HandleVisibility','off','LineWidth',1.2);

yline(1, ':k', '', 'HandleVisibility','off');
idx_1C = find(T_motor <= 1, 1);
if ~isempty(idx_1C)
    plot(t_cool(idx_1C)/60, 1, 'ko', 'MarkerSize',7,'MarkerFaceColor','k','HandleVisibility','off');
    text(t_cool(idx_1C)/60 + 0.3, 1.5, ...
        sprintf('Motor < 1^{\\circ}C at %.0f min  (margin %+.0f s vs recharge)', ...
        t_cool(idx_1C)/60, margin_s), ...
        'FontSize', 9, 'Color', [0.2 0.2 0.2]);
end

% Flag if cooldown exceeds recharge window
if margin_s < 0
    text(t_recharge/60 + 0.3, dT_motor_pk * 0.6, ...
        sprintf('\\color{red}Cooldown exceeds recharge by %.0f s', abs(margin_s)), ...
        'FontSize', 9);
end

xlabel('Time after burn cutoff [min]');
ylabel('\DeltaT above ambient [^{\circ}C]');
title(sprintf('Post-burst cooldown (%.0f s burst)', t_burst_s));
if scale == 1
    subtitle('FEM-calibrated values, free space, no RTG contact');
else
    subtitle(sprintf('Peak \\DeltaT scaled %.1f\\times from 10 s FEM (near-adiabatic); \\tau unchanged', scale));
end
lgd = legend('Location','northeast'); style_legend(lgd); ax(); fig(); hold off;

%% ── FIG T4: Multi-cycle internal temperatures ─────────────────────────
% Repeated burst-recharge cycles via superposition of exponential decay.
% Burst phase uses a linear ramp (near-adiabatic approximation).
% Peak ΔT values are scaled from 10 s FEM; time constants unchanged.
n_cyc      = 5;
t_burn_cyc = cfg.t_burst_s;
t_rchg_cyc = rogue.E_store_J / (rtg.P_design_W * mppt.eta - rtg.P_parasitic_W);
t_cyc      = t_burn_cyc + t_rchg_cyc;

tau_m = rogue.th.tau_motor_s;
tau_p = rogue.th.tau_PPS_slow_s;
tau_h = rogue.th.tau_HVG_slow_s;

% Re-derive scaled peaks locally in case block is run in isolation.
t_FEM_s_T4  = 10;
scale_T4    = cfg.t_burst_s / t_FEM_s_T4;
dT_m0 = rogue.th.dT_motor_pk_C * scale_T4;
dT_p0 = rogue.th.dT_PPS_pk_C   * scale_T4;
dT_h0 = rogue.th.dT_HVG_pk_C   * scale_T4;

dt    = 1.0;
t_tot = n_cyc * t_cyc + t_rchg_cyc;
t_ax  = 0:dt:t_tot;
T_m   = zeros(size(t_ax));
T_p   = zeros(size(t_ax));
T_h   = zeros(size(t_ax));

res_m = 0;  res_p = 0;  res_h = 0;

for cyc = 1:n_cyc
    t0 = (cyc-1) * t_cyc;
    t1 = t0 + t_burn_cyc;

    mask_burn = t_ax >= t0 & t_ax <= t1;
    mask_cool = t_ax > t1 & t_ax < cyc * t_cyc;

    frac = (t_ax(mask_burn) - t0) / t_burn_cyc;
    T_m(mask_burn) = res_m + dT_m0 * frac;
    T_p(mask_burn) = res_p + dT_p0 * frac;
    T_h(mask_burn) = res_h + dT_h0 * frac;

    t_decay = t_ax(mask_cool) - t1;
    T_m(mask_cool) = max(0, (res_m + dT_m0) * exp(-t_decay / tau_m));
    T_p(mask_cool) = max(0, (res_p + dT_p0) * exp(-t_decay / tau_p));
    T_h(mask_cool) = max(0, (res_h + dT_h0) * exp(-t_decay / tau_h));

    res_m = (res_m + dT_m0) * exp(-t_rchg_cyc / tau_m);
    res_p = (res_p + dT_p0) * exp(-t_rchg_cyc / tau_p);
    res_h = (res_h + dT_h0) * exp(-t_rchg_cyc / tau_h);
end

t_min_ax = t_ax / 60;
figure; hold on; grid on;

for cyc = 1:n_cyc
    t0_m  = (cyc-1) * t_cyc / 60;
    t1_m  = t0_m + t_burn_cyc / 60;
    y_top = max(dT_m0 * 1.15, rogue.T_op_C(2) - rogue.T_op_C(1) + 5);
    patch([t0_m t1_m t1_m t0_m], [0 0 y_top y_top], [0.9 0.9 0.9], ...
        'FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');
end

plot(t_min_ax, T_m, '-',  'LineWidth',2.0, 'Color',C(1,:), ...
    'DisplayName', sprintf('Motor (\\tau = %.0f s)', tau_m));
plot(t_min_ax, T_p, '--', 'LineWidth',1.8, 'Color',C(2,:), ...
    'DisplayName', sprintf('PPS (\\tau = %.0f s)', tau_p));
plot(t_min_ax, T_h, ':',  'LineWidth',1.8, 'Color',C(3,:), ...
    'DisplayName', sprintf('HVG (\\tau = %.0f s)', tau_h));

% Annotate residual at end of cycle 2 recharge
t_c2_end = (2 * t_cyc - t_burn_cyc) / 60;
[~, idx_c2] = min(abs(t_min_ax - t_c2_end));
if idx_c2 > 0
    plot(t_min_ax(idx_c2), T_m(idx_c2), 'o', 'MarkerSize',7, ...
        'MarkerFaceColor',C(1,:),'MarkerEdgeColor','k','HandleVisibility','off');
    text(t_min_ax(idx_c2)+0.5, T_m(idx_c2)+0.4, ...
        sprintf('Residual %.2f^{\\circ}C', T_m(idx_c2)), ...
        'FontSize', 9, 'Color', C(1,:));
end

% Absolute operating limit (Magdrive ICD): 50°C max regardless of ambient.
% Expressed as ΔT from lower operating limit (0°C cold start = worst case).
yline(rogue.T_op_C(2) - rogue.T_op_C(1), '--r', ...
    sprintf('Abs. op limit %.0f^{\\circ}C  (\\DeltaT from %.0f^{\\circ}C cold start)', ...
    rogue.T_op_C(2), rogue.T_op_C(1)), ...
    'LabelOrientation','horizontal','HandleVisibility','off');

xlabel('Time [min]');
ylabel('\DeltaT above initial [^{\circ}C]');
title(sprintf('Multi-cycle internal temperatures (%d burst-recharge cycles, %.0f s burst)', ...
    n_cyc, t_burn_cyc));
if scale_T4 == 1
    subtitle(sprintf('%.0f s burst, %.0f s recharge; FEM-calibrated; grey = burst windows', ...
        t_burn_cyc, t_rchg_cyc));
else
    subtitle(sprintf('%.0f s burst, %.0f s recharge; \\DeltaT scaled %.1f\\times from 10 s FEM; grey = burst windows', ...
        t_burn_cyc, t_rchg_cyc, scale_T4));
end
lgd = legend('Location','northeast'); style_legend(lgd); ax(); fig(); hold off;

%% ── CONSOLE SUMMARY ─────────────────────────────────────────────────────
fprintf('\n--- Thermal summary (%.0f s burst) ---\n', t_burst_s);
fprintf('  Scale factor       : %.2fx  (FEM ref 10 s)\n', scale);
fprintf('  Motor peak dT      : %.1f degC\n', dT_motor_pk);
fprintf('  PPS   peak dT      : %.1f degC\n', dT_PPS_pk);
fprintf('  HVG   peak dT      : %.1f degC\n', dT_HVG_pk);
fprintf('  Motor cooldown <1C : %.0f s  (%.1f min)\n', t_to_1C_s, t_to_1C_s/60);
fprintf('  Recharge window    : %.0f s  (%.1f min)\n', t_recharge, t_recharge/60);
if margin_s >= 0
    fprintf('  Cooldown margin    : +%.0f s  [PASS]\n', margin_s);
else
    fprintf('  Cooldown margin    : %.0f s  [FAIL — thermal accumulation expected]\n', margin_s);
end
fprintf('  Motor residual (end cycle 2) : %.2f degC\n', T_m(idx_c2));