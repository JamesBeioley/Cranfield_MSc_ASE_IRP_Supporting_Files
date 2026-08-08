%% =========================================================================
%% MicroNEP_Summary.m — Console Report
%% =========================================================================
% Structured text summary of all model results across the toolkit.
%
% Sections:
%    1. Baseline parameters
%    2. System configuration
%    3. Core capability
%       Eclipse & solar environment      (10 core profiles; unnumbered, follows 3)
%    4. Mission profile feasibility      (35 profiles if Extended_Profiles run)
%    5. Requirements analysis            (35 profiles if Extended_Profiles run)
%    6. Specific mass and RTG targets    (35 profiles if Extended_Profiles run)
%    7. Stacking analysis                (35 profiles if Extended_Profiles run)
%    8. Isp sensitivity
%    9. Frequency sweep
%   10. E_pulse scaling
%   11. Recharge and duty cycle
%   12. Thermal
%   13. Mass budget
%   14. Torque analysis
%   15. Family feasibility screen
%   16. Warlock / SuperMag deep dive (grids, eta sweep, mass band)
%
% Run order (minimum):
%   Params -> Model -> Summary
%
% Run order (full, enables Sections 4-7 at 35 profiles and Section 15):
%   Params -> Model -> Rogue_Public -> Warlock -> SuperMag ->
%   Extended_Profiles -> Summary

if ~exist('NEP','var'), error('Run MicroNEP_Model.m first.'); end

has_RP = exist('NEP_RP','var');
has_W  = exist('NEP_W', 'var');
has_SM = exist('NEP_SM','var');
has_ep = exist('ep',    'var');

rogue = NEP.params.rogue;
rtg   = NEP.params.rtg;
mppt  = NEP.params.mppt;
cfg   = NEP.params.cfg;
g0    = NEP.const.g0;

cap  = NEP.cap;
mp   = NEP.mp;
req  = NEP.req;
sm   = NEP.sm;
th_r = NEP.th_rogue;
cal  = NEP.calendar;

% Local helpers (function definitions at end of file).
sec = @(t) fprintf('\n%s\n  %s\n%s\n', repmat('=',1,72), t, repmat('=',1,72));
div = @()  fprintf('  %s\n', repmat('-',1,68));
yn  = @(tf) conditional(tf, 'YES', 'NO');

%% ── 1. BASELINE PARAMETERS ──────────────────────────────────────────────
sec('1. BASELINE PARAMETERS');
fprintf('\n  I_bit          %.0f uN.s     -> F = %.2f mN at %.0f Hz\n', ...
    rogue.I_bit_Ns*1e6, rogue.F_baseline_N*1e3, rogue.f_Hz);
fprintf('  Isp            %.0f s (design ref) | %.0f-%.0f s public range\n', ...
    rogue.Isp_s, rogue.Isp_website_s(1), rogue.Isp_website_s(2));
fprintf('  PPU chain      IES %.0f%% x HVG %.0f%% x PPS %.0f%% x plasma %.0f%% = %.1f%%\n', ...
    rogue.eta_IES*100, rogue.eta_HVG*100, rogue.eta_PPS*100, rogue.eta_plasma*100, rogue.eta_chain*100);
fprintf('  Store          %.0f kJ accessible / %.0f kJ full | %.1f J/pulse | %.0f s burst\n', ...
    rogue.E_store_J/1e3, rogue.E_store_full_J/1e3, rogue.E_per_pulse_J, rogue.t_burst_max_s);
fprintf('  Propellant     %.0f g (identity pending)\n', rogue.m_prop_kg*1e3);
fprintf('  alpha (E_p)    %.1f (literature default)\n', cfg.alpha_Ipulse);

%% ── 2. SYSTEM CONFIGURATION ────────────────────────────────────────────
sec('2. SYSTEM CONFIGURATION');

fprintf('\n  Am-241 RTG (Perpetual Atomics / University of Leicester)\n');
fprintf('    Output      %.0f We design  (lab %.1f-%.1f We)\n', ...
    rtg.P_design_W, rtg.P_lab_min_W, rtg.P_lab_max_W);
fprintf('    TEGs        %d modules | %.0f-%.0f%% eta\n', ...
    rtg.n_TEG, min(NEP.teg.eta_pct), max(NEP.teg.eta_pct));
fprintf('    Mass        %.1f kg\n', rtg.mass_kg);
fprintf('    Sp. mass    %.2f kg/We\n', rtg.specific_mass_kgWe);
fprintf('    EM heater   %.1f W / %.1f V (substitutes for Am-241 in engineering phase)\n', ...
    NEP.params.heater.P_W, NEP.params.heater.V_V);

rtg_plus = NEP.params.rtg_plus;
fprintf('\n  PA Am-241 RTG+\n');
fprintf('    Output      %.0f We design (same %.1f kg form factor; ~20%% efficiency improvement)\n', ...
    rtg_plus.P_design_W, rtg_plus.mass_kg);
fprintf('    Mass        %.1f kg\n', rtg_plus.mass_kg);
fprintf('    Sp. mass    %.2f kg/We  (vs baseline %.2f kg/We; %.0fx improvement)\n', ...
    rtg_plus.specific_mass_kgWe, rtg.specific_mass_kgWe, ...
    rtg.specific_mass_kgWe / rtg_plus.specific_mass_kgWe);
fprintf('    Status      Direction confirmed; output pending characterisation test.\n');

fprintf('\n  PA RSG Stirling generators (estimated from Mesalam 2024 Fig 2)\n');
rsg_P   = [35,   100,   200];
rsg_m   = [22.5, 75.0,  110.0];
rsg_lbl = {'RSG-35', 'RSG-100', 'RSG-200'};
for r = 1:numel(rsg_P)
    fprintf('    %-10s  %.0f We | %.1f kg | %.2f kg/We\n', ...
        rsg_lbl{r}, rsg_P(r), rsg_m(r), rsg_m(r)/rsg_P(r));
end
fprintf('    Note: RSG-35/100 estimated by interpolation; RSG-200 from Mesalam Table 7/8.\n');

fprintf('\n  MPPT\n');
fprintf('    eta = %.0f%% (estimate) | %.0f V regulated | %.2f A max charge current\n', ...
    mppt.eta*100, mppt.V_out_V, mppt.I_max_A);

fprintf('\n  Magdrive Rogue 3\n');
fprintf('    Thrust      %.2f mN  (F = I_bit x f = %.0f uN.s x %.0f Hz)\n', ...
    rogue.F_baseline_N*1e3, rogue.I_bit_Ns*1e6, rogue.f_Hz);
fprintf('    Isp         %.0f s design ref | %.0f-%.0f s public range\n', ...
    rogue.Isp_s, rogue.Isp_website_s(1), rogue.Isp_website_s(2));
fprintf('    T/P         %.1f mN/kW  | ion 30-40, Hall 50-70, PTFE-PPT 5-13\n', rogue.T_per_P_mNkW);
fprintf('    Mass        %.2f kg wet (%.2f kg dry)\n', rogue.mass_kg, rogue.mass_dry_kg);
fprintf('    Propellant  %.0f g | PPU %.0f V / %.1f A max charge\n', ...
    rogue.m_prop_kg*1e3, rogue.V_PPU_V, rogue.I_charge_max_A);

fprintf('\n  System (RTG + Rogue, excl. MPPT and coupling)\n');
fprintf('    Mass        %.2f kg lower bound\n', cfg.m_prop_sys_kg);
fprintf('    Sp. mass    %.2f kg/We  (system)  |  %.2f kg/We  (RTG source only)\n', ...
    NEP.sm.alpha.system_kgWe, rtg.specific_mass_kgWe);
fprintf('    Sp. power   %.2f-%.2f W/kg  (lab min -> design)  | MMRTG ~2.8 W/kg\n', ...
    NEP.mass.sp_power_min_Wkg, NEP.mass.sp_power_max_Wkg);

%% ── 3. CORE CAPABILITY ─────────────────────────────────────────────────
sec('3. CORE CAPABILITY');
fprintf('\n  Lifetime dV at %.0f kg reference s/c (exact Tsiolkovsky):\n\n', cfg.m_ref_kg);
fprintf('  %-18s |  %10s  %10s  %10s\n', 'I_bit', '1M pulses', '10M pulses', '200M pulses');
div();
for k = 1:numel(cap.I_bit_lines_Ns)
    I_b   = cap.I_bit_lines_Ns(k);
    n_vec = [1e6, 10e6, 200e6];
    dV_vec = arrayfun(@(n) dv_life(I_b, n, cfg.m_ref_kg, cfg.m_prop_sys_kg, rogue.Isp_s, g0), n_vec);
    tag = ''; if abs(I_b - rogue.I_bit_Ns) < 1e-9, tag = '  baseline'; end
    fprintf('  %4.0f uN.s          |  %9.2f   %9.2f   %9.1f m/s%s\n', ...
        I_b*1e6, dV_vec(1), dV_vec(2), dV_vec(3), tag);
end
fprintf('\n  Duty-cycle ceiling at %.0f kg (%.0f s burst, %.0f Hz): %.1f m/s/yr\n', ...
    cfg.m_ref_kg, rogue.t_burst_max_s, rogue.f_Hz, NEP.dV_duty_ceiling);

fprintf('\n  Total impulse cross-check:\n');
fprintf('    Pulse model (I_bit x 10M):       %.0f Ns\n', NEP.I_total_current_Ns);
fprintf('    Propellant-implied (200 g, %.0f s Isp): %.0f Ns\n', rogue.Isp_s, NEP.I_total_website_Ns);
fprintf('    Ratio: %.0fx\n', NEP.I_total_website_Ns / NEP.I_total_current_Ns);

fprintf('\n  Calendar life from %.0fM-pulse budget at %.0f Hz (%.1f h total firing):\n\n', ...
    cal.N_pulses/1e6, cal.f_Hz, cal.t_fire_total_s/3600);
fprintf('  %-12s | %12s | %12s\n', 'Duty cycle', 'Life [days]', 'Life [years]');
div();
for i = 1:numel(cal.duty_frac)
    tag = ''; if abs(cal.duty_pct(i) - cal.model_duty_pct) < 1e-6, tag = '  baseline'; end
    fprintf('  %10.3f%% | %12.1f | %12.2f%s\n', cal.duty_pct(i), cal.life_days(i), cal.life_years(i), tag);
end


%% ── ECLIPSE & SOLAR ENVIRONMENT (10 core profiles) ──────────────────────
sec('ECLIPSE & SOLAR ENVIRONMENT  (10 core profiles, worst-case beta = 0)');
fprintf('\n  Method: circular-orbit eclipse fraction = arcsin(R_body / R_orbit) / pi.\n');
fprintf('  NRHO uses CAPSTONE reference; L1/L2 uses JWST reference.\n');
fprintf('  Solar flux S = S0 / r_AU^2,  S0 = 1361 W/m^2.\n\n');

ecl_R_E  = 6371.0;  ecl_mu_E  = 398600.4;   % Earth
ecl_R_Mn = 1737.4;  ecl_mu_Mn = 4902.8;     % Moon
ecl_R_Eu = 1560.8;  ecl_mu_Eu = 3202.7;     % Europa
ecl_R_Ma = 3389.5;  ecl_mu_Ma = 42828.0;    % Mars
ecl_S0   = 1361.0;

prd = @(R,mu) 2*pi*sqrt(R^3/mu)/60;   % circular orbit period [min]
fec = @(Rb,Ro) asind(Rb/Ro)/180;      % worst-case eclipse fraction (beta=0)

% Table columns: {T_min, f_ecl, r_AU, note}  — indexed to match mp(1:10)
% Order MUST match Model profile_defs: VLEO, Asteroid, Frozen-lunar(+PSR),
% NRHO, L1/L2, Phobos, GEO-proximity, Icy-moon, SE-L1, Apophis.
% Special cases: NaN T_min = no orbital period (hover / no eclipse); f_ecl
% hardcoded where a non-circular reference applies (NRHO, GEO equinox).
% All circular-orbit values verified against Mission_Analysis eclipse table.
ed = { ...
  prd(ecl_R_E +340,  ecl_mu_E ), fec(ecl_R_E,  ecl_R_E +340  ), 1.00, '16 thermal cycles/day; ~340 km design pt'; ...   % 1 VLEO
  NaN,                           0,                               2.50, 'Hovering; asteroid too small to eclipse (2.5 AU)'; ... % 2 Asteroid
  prd(ecl_R_Mn+50,   ecl_mu_Mn), 0.317,                           1.00, '13 cycles/day; PSR target dark; year-avg beta (worst case 42.5%)'; ... % 3 Frozen lunar (+PSR)
  9360,                          0.042,                           1.00, '6.5-day orbit; ~6.5 hr max (CAPSTONE ref.)'; ...    % 4 NRHO
  NaN,                           0,                               1.00, '~6-month period; JWST orbit avoids eclipses'; ...   % 5 L1/L2 halo
  prd(9376, ecl_mu_Ma),          fec(ecl_R_Ma, 9376            ), 1.52, 'Eclipse by Mars; 43% solar flux at 1.52 AU'; ...    % 6 Phobos
  1440,                          fec(ecl_R_E,  ecl_R_E +35786 ), 1.00, 'Equinox only (~23 d/yr); 0.6% annual avg'; ...      % 7 GEO proximity
  prd(ecl_R_Eu+100,  ecl_mu_Eu), fec(ecl_R_Eu, ecl_R_Eu+100  ), 5.20, '+Jupiter shadow 2.9 hr/3.55 d; 4% solar; RADIATION dose drives design'; ... % 8 Icy moon
  NaN,                           0,                               0.99, 'L1 halo sunward of Earth; eclipse-free (DSCOVR-like)'; ... % 9 SE-L1 sentinel
  NaN,                           0,                               1.00, 'Hovering at Apophis; no orbital eclipse (~1 AU)'; ...   % 10 Apophis
};

fprintf('  %-36s | %9s | %7s | %9s | %9s | Note\n', ...
    'Profile', 'Period', 'Max ecl', 'Ecl dur', 'S [W/m2]');
div();
for i = 1:size(ed,1)
    T_min  = ed{i,1};  f_ecl  = ed{i,2};
    r_AU   = ed{i,3};  note   = ed{i,4};
    S_flux = ecl_S0 / r_AU^2;
    lbl    = mp(i).label;
    if isnan(T_min)
        T_str = '—';  ecl_str = '~0%';  dur_str = 'negl.';
    elseif T_min >= 1440
        T_str   = sprintf('%.1f d',    T_min/1440);
        ecl_str = sprintf('%.1f%%',    f_ecl*100);
        dur_str = sprintf('%.0f min',  f_ecl*T_min);
    else
        T_str   = sprintf('%.0f min',  T_min);
        ecl_str = sprintf('%.1f%%',    f_ecl*100);
        dur_str = sprintf('%.0f min',  f_ecl*T_min);
    end
    fprintf('  %-36s | %9s | %7s | %9s | %9.0f | %s\n', ...
        lbl, T_str, ecl_str, dur_str, S_flux, note);
end
fprintf('\n  Battery avoided by RTG (50 W bus, 15 kJ/kg Li-ion, 80%% DoD):\n');
fprintf('  VLEO/frozen-lunar ~9-12 kg;  GEO equinox ~14 kg;  Europa ~12 kg per eclipse.\n');
fprintf('  Eclipse-free (no battery driver): asteroid, L1/L2, SE-L1, Apophis.\n\n');

%% ── 4. MISSION PROFILE FEASIBILITY ─────────────────────────────────────
if has_ep
    prof4 = ep;  n_prof4 = numel(ep);
    src4  = sprintf('%d profiles (Extended_Profiles)', n_prof4);
else
    prof4 = mp;  n_prof4 = numel(mp);
    src4  = sprintf('%d profiles (core model)', n_prof4);
end

sec(sprintf('4. MISSION PROFILE FEASIBILITY (I_bit = %.0f uN.s, %s)', ...
    rogue.I_bit_Ns*1e6, src4));
fprintf('\n  Dual-constraint: duty-cycle ceiling AND pulse-life ceiling must be met.\n');
fprintf('  Duty ceiling is annual (m/s/yr). Pulse-life is total deliverable (m/s).\n');
fprintf('  Closure here is impulse-based; mass-fit is screened in Section 6.\n\n');

fprintf('  %-40s | %5s | %5s | %8s | %8s | %8s | %5s | %5s\n', ...
    'Profile  (* = core 10)', 'dV', 'm_sc', 'Duty max', 'Life@1M', 'Life@10M', '@1M', '@10M');
fprintf('  %-40s | %5s | %5s | %8s | %8s | %8s | %5s | %5s\n', ...
    '', 'm/s', 'kg', 'm/s/yr', 'm/s', 'm/s', '', '');
div();
% core_lbls must match the labels actually in use: mp's short-form labels
% when running off the 10-profile core, or Extended_Profiles' longer-form
% labels for the same 10 profiles when the 35-profile set (ep) is active.
if has_ep
    core_lbls = {'VLEO drag comp. (~250-350 km)', 'Asteroid proximity ops', ...
                 'Frozen lunar orbit (incl. PSR support)', 'NRHO / cislunar relay', ...
                 'L1/L2 halo orbit SK', 'Phobos proximity ops', ...
                 'GEO co-orbital proximity (insp/guardian)', 'Icy moon / ocean world orbiter', ...
                 'SE-L1 space weather sentinel', 'Apophis 2029 proximity / companion'};
else
    core_lbls = {mp.label};
end
for i = 1:n_prof4
    p     = prof4(i);
    dV1s  = fmt_dv(p.dV_life_1M_ms);
    dV10s = fmt_dv(p.dV_life_10M_ms);
    lbl4  = p.label;
    if any(strcmp(core_lbls, lbl4)), lbl4 = ['* ' lbl4]; end
    fprintf('  %-40s | %5.0f | %5.0f | %8.1f | %8s | %8s | %5s | %5s\n', ...
        lbl4, p.dV_req_ms, p.m_sc_kg, p.dV_duty_max_ms, ...
        dV1s, dV10s, yn(p.feasible_1M), yn(p.feasible_10M));
end

%% ── 5. REQUIREMENTS ANALYSIS ───────────────────────────────────────────
if has_ep
    prof5 = ep;  n_prof5 = numel(ep);
    src5  = sprintf('%d profiles (Extended_Profiles)', n_prof5);
else
    prof5 = [];  n_prof5 = numel(req);
    src5  = sprintf('%d profiles (core model)', n_prof5);
end

sec(sprintf('5. REQUIREMENTS ANALYSIS (I_bit = %.0f uN.s, Isp = %.0f s, %s)', ...
    rogue.I_bit_Ns*1e6, rogue.Isp_s, src5));
fprintf('\n  Per profile: pulses needed at baseline I_bit, I_bit needed at 10M pulses,\n');
fprintf('  and target alpha_sys to fit closing stack in %.0f%% of m_sc.\n\n', sm.f_prop_ref*100);

fprintf('  %-40s | %5s | %8s | %11s | %10s | %4s | %9s\n', ...
    'Profile  (* = core 10)', 'dV', 'I_req', 'N_req@base', 'I_req@10M', 'Tier', 'a_target');
fprintf('  %-40s | %5s | %8s | %11s | %10s | %4s | %9s\n', ...
    '', 'm/s', 'Ns', '(M pulses)', '(uN.s)', '', '(kg/We)');
div();
if ~exist('core_lbls','var'), core_lbls = {mp.label}; end
if has_ep
    for i = 1:n_prof5
        p = prof5(i);
        if p.tier > numel(cfg.req_tiers_Ns), tier_s = '>T3';
        else, tier_s = sprintf('T%d', p.tier); end
        a_target = sm.f_prop_ref * p.m_sc_kg / rtg.P_design_W;
        lbl5 = p.label;
        if any(strcmp(core_lbls, lbl5)), lbl5 = ['* ' lbl5]; end
        fprintf('  %-40s | %5.0f | %8.0f | %11.1f | %10.1f | %4s | %9.2f\n', ...
            lbl5, p.dV_req_ms, p.I_total_req_Ns, ...
            p.N_req_at_nom_M, p.I_req_at_10M_uNs, tier_s, a_target);
    end
else
    for i = 1:n_prof5
        if req(i).tier > numel(cfg.req_tiers_Ns), tier_s = '>T3';
        else, tier_s = sprintf('T%d', req(i).tier); end
        a_target = sm.f_prop_ref * req(i).m_sc_kg / rtg.P_design_W;
        lbl5 = req(i).label;
        if any(strcmp(core_lbls, lbl5)), lbl5 = ['* ' lbl5]; end
        fprintf('  %-40s | %5.0f | %8.0f | %11.1f | %10.1f | %4s | %9.2f\n', ...
            lbl5, req(i).dV_req_ms, req(i).I_total_req_Ns, ...
            req(i).N_req_at_nom_M, req(i).I_bit_req_at_10M_uNs, tier_s, a_target);
    end
end

fprintf('\n  Tier thresholds:\n');
for t = 1:numel(cfg.req_tiers_Ns)
    fprintf('    %s: I_total <= %.0f Ns\n', cfg.req_tier_labels{t}, cfg.req_tiers_Ns(t));
end
fprintf('  a_target = %.0f%% x m_sc / P_e_RTG. Current alpha_sys %.2f kg/We; fit when alpha_sys <= a_target.\n', ...
    sm.f_prop_ref*100, sm.alpha.system_kgWe);

%% ── 6. SPECIFIC MASS AND RTG TARGETS ───────────────────────────────────
sec('6. SPECIFIC MASS AND RTG TARGETS');
fprintf('\n  For each profile: maximum RTG specific mass alpha_RTG that fits the\n');
fprintf('  %.0f%% propulsion-system mass allowance after the minimum Rogue stack.\n\n', sm.f_prop_ref*100);

fprintf('  Current RTG  %.2f kg/We  (%.1f kg at %.0f We)\n', ...
    rtg.specific_mass_kgWe, rtg.mass_kg, rtg.P_design_W);
fprintf('  System alpha %.2f kg/We  (RTG + single Rogue, %.1f kg at %.0f We)\n\n', ...
    sm.alpha_single_kgWe, cfg.m_prop_sys_kg, rtg.P_design_W);

fprintf('  %-38s | %5s | %5s | %6s | %11s | %12s | %8s\n', ...
    'Profile', 'm_sc', 'nRog', 'I_req', 'alpha_max', 'Pwr at mass', 'Fits now');
fprintf('  %-38s | %5s | %5s | %6s | %11s | %12s | %8s\n', ...
    '', 'kg', '', 'Ns', '(kg/We)', sprintf('@%.1f kg', rtg.mass_kg), '');
div();

I_per_R_Ns = rogue.I_bit_Ns * rogue.n_pulses_ambition;
n_max      = cfg.n_stk_max;

if has_ep
    for i = 1:numel(ep)
        lbl_i = ep(i).label;  m_sc_i = ep(i).m_sc_kg;  I_req_i = ep(i).I_total_req_Ns;
        nR    = max(1, ceil(I_req_i / I_per_R_Ns));
        m_bud = sm.f_prop_ref * m_sc_i - nR * rogue.mass_kg;
        if nR > n_max || m_bud <= 0
            a_s = 'N/A';  p_s = 'N/A';  fit_s = 'NO';
        else
            a_mx  = m_bud / rtg.P_design_W;
            a_s   = sprintf('%.2f', a_mx);
            p_s   = sprintf('%.1f We', rtg.mass_kg / a_mx);
            fit_s = yn(rtg.specific_mass_kgWe <= a_mx);
        end
        fprintf('  %-38s | %5.0f | %5.0f | %6.0f | %11s | %12s | %8s\n', ...
            lbl_i, m_sc_i, nR, I_req_i, a_s, p_s, fit_s);
    end
else
    for i = 1:numel(sm.threshold)
        th = sm.threshold(i);
        if isnan(th.alpha_power_max_kgWe)
            a_s = 'N/A'; p_s = 'N/A'; fit_s = 'NO';
        else
            a_s   = sprintf('%.2f', th.alpha_power_max_kgWe);
            p_s   = sprintf('%.1f We', th.target_rtg_power_We_at_mass);
            fit_s = yn(th.fit_now);
        end
        fprintf('  %-38s | %5.0f | %5.0f | %6.0f | %11s | %12s | %8s\n', ...
            th.label, th.m_sc_kg, th.n_rogue_req, th.I_req_Ns, a_s, p_s, fit_s);
    end
end

% Table 6a — Alpha decomposition for the confirmed architecture.
fprintf('\n  Table 6a - Alpha decomposition (Rogue + RTG, single unit, %.0f We)\n', ...
    rtg.P_design_W);
fprintf('  %-32s | %8s | %12s\n', 'Component', 'Mass[kg]', 'Alpha');
div();
fprintf('  %-32s | %8.2f | %7.3f kg/We\n', 'Power source (RTG)',     sm.alpha.m_pwr_kg,  sm.alpha.source_kgWe);
fprintf('  %-32s | %8.2f | %7.3f kg/We\n', 'PMAD (PPU+store+harness)', sm.alpha.m_PMAD_kg, sm.alpha.PMAD_kgWe);
fprintf('  %-32s | %8.2f | %7.3f kg/N \n', 'Thruster head',           sm.alpha.m_head_kg, sm.alpha.thr_kgN);
div();
fprintf('  %-32s | %8.2f | %7.3f kg/We\n', 'System (sum)',            sm.alpha.m_pwr_kg + sm.alpha.m_PMAD_kg + sm.alpha.m_head_kg, sm.alpha.system_kgWe);
fprintf('  %-32s | %8s | %7.1f kg/We jet  (P_jet %.2f W during pulse)\n', ...
    'System per kW jet, instantaneous', '', sm.alpha.jet_inst_kgWe, sm.alpha.P_jet_inst_W);
fprintf('  %-32s | %8s | %7.0f kg/We jet  (duty-averaged %.2f%%)\n', ...
    'System per kW jet, duty-averaged', '', sm.alpha.jet_avg_kgWe, sm.alpha.duty*100);

% Table 6b — Alpha benchmark ladder (literature comparators).
fprintf('\n  Table 6b - Specific-mass benchmark ladder (literature)\n');
fprintf('  %-30s | %5s | %9s | %11s | %s\n', ...
    'System', 'Class', 'P_e [We]', 'alpha[kg/We]', 'vs. PA RTG');
div();
for i = 1:numel(sm.bench.label)
    if sm.bench.confirmed(i), tag = '*'; else, tag = ' '; end
    fprintf('  %s%-29s | %5s | %9.0f | %11.3f | %7.2fx\n', ...
        tag, sm.bench.label{i}, sm.bench.class{i}, sm.bench.P_e_W(i), sm.bench.alpha_kgWe(i), ...
        sm.bench.alpha_kgWe(i) / rtg.specific_mass_kgWe);
end
fprintf('  * confirmed engineering value; others are literature point estimates.\n');

% Table 6c — Per-profile alpha_max across f_prop sweep (core 10 profiles only).
if ~has_ep
    fprintf('\n  Table 6c - Max permitted alpha_RTG [kg/We] vs propulsion-mass fraction\n');
    fprintf('             (single RTG at %.0f We paired with minimum Rogue stack)\n', rtg.P_design_W);
    fp = cfg.prop_mass_fraction_sweep;
    fprintf('  %-38s |', 'Profile');
    for k = 1:numel(fp), fprintf(' %4.0f%%', 100*fp(k)); end
    fprintf('\n  %s\n', repmat('-', 1, 40 + 6*numel(fp)));
    for i = 1:numel(sm.threshold)
        th = sm.threshold(i);
        fprintf('  %-38s |', th.label);
        for k = 1:numel(fp)
            v = th.alpha_power_max_grid_kgWe(k);
            if isnan(v) || v <= 0
                fprintf('   N/A');
            else
                fprintf(' %5.2f', v);
            end
        end
        fprintf('\n');
    end
    fprintf('  Current PA RTG: %.2f kg/We. Cells >= this value indicate the profile closes.\n', ...
        rtg.specific_mass_kgWe);
end

% Table 6d — Minimum-mass closing stack.
fprintf('\n  Table 6d - Minimum-mass closing stack (n_R x n_T, search 1..%d)\n', n_max);
fprintf('  %-38s | %3s | %3s | %7s | %9s | %s\n', ...
    'Profile', 'nR', 'nT', 'mass_kg', 'alpha_sys', sprintf('fits @%.0f%%?', sm.f_prop_ref*100));
fprintf('  %s\n', repmat('-', 1, 80));

if has_ep
    for i = 1:numel(ep)
        I_req_i = ep(i).I_total_req_Ns;
        nR_req  = max(1, ceil(I_req_i / I_per_R_Ns));
        if nR_req > n_max
            fprintf('  %-38s | %3s | %3s | %7s | %9s | %s\n', ...
                ep(i).label, sprintf('>%d',n_max), '-', '-', '-', sprintf('NO (need n_R>%d)',n_max));
            continue;
        end
        m  = nR_req * rogue.mass_kg + rtg.mass_kg;
        a  = m / rtg.P_design_W;
        fits = m <= sm.f_prop_ref * ep(i).m_sc_kg;
        fprintf('  %-38s | %3d | %3d | %7.1f | %7.2f   | %s\n', ...
            ep(i).label, nR_req, 1, m, a, yn(fits));
    end
else
    for i = 1:numel(sm.threshold)
        th  = sm.threshold(i);
        nR_req = max(1, ceil(th.I_req_Ns / I_per_R_Ns));
        if nR_req > n_max
            fprintf('  %-38s | %3s | %3s | %7s | %9s | %s\n', ...
                th.label, sprintf('>%d',n_max), '-', '-', '-', sprintf('NO (need n_R>%d)',n_max));
            continue;
        end
        m  = nR_req * rogue.mass_kg + rtg.mass_kg;
        a  = m / rtg.P_design_W;
        fits = m <= sm.f_prop_ref * th.m_sc_kg;
        fprintf('  %-38s | %3d | %3d | %7.1f | %7.2f   | %s\n', ...
            th.label, nR_req, 1, m, a, yn(fits));
    end
end
fprintf('  Lightest stack always uses n_T=1 (RTG mass dominates); duty = single-RTG value.\n');

%% ── 7. STACKING ANALYSIS ───────────────────────────────────────────────
sec('7. STACKING ANALYSIS  (n_rogue x n_rtg)');

stk   = NEP.stk;
n_stk = cfg.n_stk_max;

fprintf('\n  Equal-stack summary (n_Rogue = n_RTG, ref s/c %.0f kg / %.0f kg):\n\n', ...
    NEP.stk_m_sc(1), NEP.stk_m_sc(2));
fprintf('  %-4s | %8s | %7s | %9s | %7s | %7s | %9s | %9s\n', ...
    'NxN', 'Sys[kg]', 'Burst[s]', 'Rchg[min]', 'Duty[%]', 'F[mN]', ...
    sprintf('dV@%dkg',NEP.stk_m_sc(1)), sprintf('dV@%dkg',NEP.stk_m_sc(2)));
div();
for n = 1:n_stk
    s    = stk(n,n);
    dv1s = fmt_dv(s.dV_life_ms(1));
    dv2s = fmt_dv(s.dV_life_ms(2));
    fprintf('  %dx%-3d | %8.1f | %7.0f | %9.1f | %7.2f | %7.2f | %9s | %9s\n', ...
        n, n, s.m_sys_kg, s.t_burst_s, s.t_rchg_min, s.duty*100, s.F_N*1e3, dv1s, dv2s);
end

if has_ep
    prof7 = ep;  n_prof7 = numel(ep);
    src7  = sprintf('%.0f kg s/c, %.0f uN.s, %d profiles', NEP.stk_m_sc(1), rogue.I_bit_Ns*1e6, n_prof7);
else
    prof7 = mp;  n_prof7 = numel(mp);
    src7  = sprintf('%.0f kg s/c, %.0f uN.s, %d profiles', NEP.stk_m_sc(1), rogue.I_bit_Ns*1e6, n_prof7);
end

fprintf('\n  Minimum equal-stack to close each profile (%s):\n\n', src7);
fprintf('  %-38s | %5s | %14s\n', 'Profile', 'dV req', 'Min stack');
div();
for i = 1:n_prof7
    p     = prof7(i);
    dV_r  = p.dV_req_ms;
    min_n = 'INFEAS';
    if has_ep
        % Compute minimum n×n stack from duty ceiling and dV
        for n = 1:n_stk
            s_nn = stk(n,n);
            dV_duty_n = s_nn.F_N * s_nn.duty * (365.25*86400) / NEP.stk_m_sc(1);
            dV_life_n = dv_life(rogue.I_bit_Ns, n*rogue.n_pulses_ambition, ...
                NEP.stk_m_sc(1), cfg.m_prop_sys_kg, rogue.Isp_s, g0);
            if dV_duty_n >= dV_r && dV_life_n >= dV_r
                min_n = sprintf('%dx%d  (%.1f m/s)', n, n, dV_life_n);
                break;
            end
        end
    else
        for n = 1:n_stk
            if NEP.stk_unlock(i,1).feasible_grid(n,n)
                min_n = sprintf('%dx%d  (%.1f m/s)', n, n, stk(n,n).dV_life_ms(1));
                break;
            end
        end
    end
    fprintf('  %-38s | %5.0f | %s\n', p.label, dV_r, min_n);
end

%% ── 8. ISP SENSITIVITY ─────────────────────────────────────────────────
sec(sprintf('8. ISP SENSITIVITY  (%.0f kg s/c, single Rogue, 10M pulses, 200 g propellant)', cfg.m_ref_kg));
fprintf('\n  ICD baseline 1500 s | website range %.0f-%.0f s\n\n', ...
    rogue.Isp_website_s(1), rogue.Isp_website_s(2));

fprintf('  %8s | %10s | %13s | %12s\n', 'Isp [s]', 'dV [m/s]', 'I_impl [Ns]', 'N_impl [M]');
div();
for ii = 1:numel(NEP.sw_Isp)
    s = NEP.sw_Isp(ii);
    tag = ''; if s.Isp_s == rogue.Isp_s, tag = '  design ref'; end
    fprintf('  %8.0f | %10.2f | %13.0f | %12.1f%s\n', ...
        s.Isp_s, s.dV_ref_ms, s.I_total_implied_Ns, s.N_implied_M, tag);
end

fprintf('\n  Propellant ceiling (200 g prop): %.0f s -> %.0f Ns | %.0f s -> %.0f Ns | %.0f s -> %.0f Ns\n', ...
    150,  150*g0*0.2, 1000, 1000*g0*0.2, 1800, 1800*g0*0.2);
fprintf('  Pulse-model %.0f Ns: gap %.0fx at 1800 s Isp -> %.1fx at 150 s (current est.)\n', ...
    NEP.I_total_current_Ns, 1800*g0*0.2/NEP.I_total_current_Ns, 150*g0*0.2/NEP.I_total_current_Ns);

%% ── 9. FREQUENCY SWEEP ─────────────────────────────────────────────────
sec(sprintf('9. FREQUENCY SWEEP  (%.1f J/pulse, %.0f kJ store, I_bit = %.0f uN.s)', ...
    rogue.E_per_pulse_J, rogue.E_store_J/1e3, rogue.I_bit_Ns*1e6));
fprintf('\n');
fprintf('  %6s | %8s | %9s | %7s | %7s | %10s | %10s\n', ...
    'f [Hz]', 'Burst[s]', 'Rchg[min]', 'Duty[%]', 'F[mN]', 'dV[m/s/yr]', 'Life[days]');
div();
for fi = 1:numel(NEP.sw_freq)
    s    = NEP.sw_freq(fi);
    dv_s = fmt_dv(s.dV_ms);
    tag  = ''; if s.f_Hz == rogue.f_Hz, tag = '  baseline'; end
    fprintf('  %6.0f | %8.0f | %9.2f | %7.2f | %7.3f | %10s | %10.0f%s\n', ...
        s.f_Hz, s.t_max_s, s.t_rchg_min, s.duty*100, s.F_N*1e3, dv_s, s.life_10M_days, tag);
end

fprintf('  I_total per store depletion = I_bit x E_store/E_pulse = %.1f mNs — invariant at all f.\n', ...
    rogue.I_bit_Ns * rogue.E_store_J / rogue.E_per_pulse_J * 1e3);
fprintf('  Frequency selects thrust level and burst duration only; not lifetime dV or per-burst impulse.\n');

%% ── 10. E_PULSE SCALING ────────────────────────────────────────────────
sec(sprintf('10. E_PULSE SCALING  (alpha = %.1f, %.0f kJ store, 10M pulses)', ...
    cfg.alpha_Ipulse, rogue.E_store_J/1e3));
fprintf('\n  I_bit = I_bit_ref * (E_pulse / E_pulse_ref)^alpha\n\n');

fprintf('  %4s | %6s | %12s | %13s\n', 'alpha', 'Ep[J]', 'I_bit[uN.s]', 'dV_life[m/s]');
div();
for ai = 1:numel(cfg.alpha_sweep)
    for ei = 1:numel(cfg.E_pulse_sweep_J)
        tag = '';
        if cfg.E_pulse_sweep_J(ei) == rogue.E_per_pulse_J && ...
                abs(cfg.alpha_sweep(ai) - cfg.alpha_Ipulse) < 0.01
            tag = '  reference';
        end
        fprintf('  %4.1f | %6.1f | %12.1f | %13.3f%s\n', ...
            cfg.alpha_sweep(ai), cfg.E_pulse_sweep_J(ei), ...
            NEP.sw_epulse.I_bit_grid(ai,ei)*1e6, ...
            NEP.sw_epulse.dV_life_grid(ai,ei), tag);
    end
    if ai < numel(cfg.alpha_sweep), fprintf('\n'); end
end

%% ── 11. RECHARGE AND DUTY CYCLE ────────────────────────────────────────
sec('11. RECHARGE AND DUTY CYCLE');
fprintf('\n  Design: %.0f We x %.0f%% MPPT - %.0f mW parasitic = %.2f W net\n', ...
    rtg.P_design_W, mppt.eta*100, rtg.P_parasitic_W*1000, NEP.pt.P_net_W);
fprintf('  Recharge: %.1f s (%.2f min) at %.0f s burst -> duty = %.2f%%\n\n', ...
    NEP.pt.t_recharge_s, NEP.pt.t_recharge_min, cfg.t_burst_s, NEP.pt.duty_cycle*100);

fprintf('  %10s | %11s | %8s | %12s\n', 'P_RTG [We]', 'Rchg [min]', 'Duty [%]', 'dV [m/s/yr]');
div();
for p = 1:numel(NEP.sw_power)
    dv_s = fmt_dv(NEP.sw_power(p).dV_ms);
    fprintf('  %10.1f | %11.1f | %8.2f | %12s\n', ...
        NEP.sw_power(p).P_We, NEP.sw_power(p).t_min, NEP.sw_power(p).duty*100, dv_s);
end

%% ── 12. THERMAL ────────────────────────────────────────────────────────
sec('12. THERMAL  (figures in MicroNEP_Thermal_Plots.m)');
fprintf('\n  RTG fin equilibrium (deep space):\n');
fprintf('    Design  (%.0f We out): %.1f degC  [%s, margin %+.1f degC vs adhesive]\n', ...
    rtg.P_design_W, NEP.th_rtg.T_eq_C, ...
    okflag(NEP.th_rtg.adhesive_ok), NEP.th_rtg.adhesive_margin_C);
fprintf('    Lab-min (%.1f We out): %.1f degC  [%s, margin %+.1f degC vs adhesive]\n', ...
    rtg.P_lab_min_W, NEP.th_rtg.T_eq_lab_C, ...
    okflag(NEP.th_rtg.adhesive_ok_lab), NEP.th_rtg.adhesive_margin_lab_C);
fprintf('    Limits: adhesive %.0f degC | LEMO %.0f degC | housing %d degC isothermal\n', ...
    rtg.T_adhesive_C(1), rtg.T_lemo_C(1), rtg.T_housing_C);
if ~NEP.th_rtg.adhesive_ok
    fprintf('    ** FLAG: design-case fin sits below the adhesive limit. Mitigation\n');
    fprintf('    ** required: reduced fin area, heater bias, or limit requalification.\n');
end

if exist('th_scaled','var') && isstruct(th_scaled)
    th_t_burst    = th_scaled.t_burst_s;
    th_scale      = th_scaled.scale;
    th_dT_motor   = th_scaled.dT_motor_pk_C;
    th_dT_PPS     = th_scaled.dT_PPS_pk_C;
    th_dT_HVG     = th_scaled.dT_HVG_pk_C;
    th_src        = sprintf('%.0f s burst, scaled %.2fx from 10 s FEM', th_t_burst, th_scale);
else
    th_t_burst    = 10;
    th_scale      = 1.0;
    th_dT_motor   = rogue.th.dT_motor_pk_C;
    th_dT_PPS     = rogue.th.dT_PPS_pk_C;
    th_dT_HVG     = rogue.th.dT_HVG_pk_C;
    th_src        = '10 s FEM ref; run Thermal_Plots before Summary for scaled values';
end

t_cool_motor_s = -rogue.th.tau_motor_s    * log(1.0 / th_dT_motor);
t_cool_PPS_s   = -rogue.th.tau_PPS_fast_s * log(1.0 / th_dT_PPS);
t_cool_HVG_s   = -rogue.th.tau_HVG_fast_s * log(1.0 / th_dT_HVG);

fprintf('\n  Rogue burst (%s):\n', th_src);
fprintf('    Internal/external dT ratio: %.1fx  (FEM ref, invariant)\n', th_r.dT_ratio);
fprintf('    Peak dT  : Motor %.1f degC | PPS %.1f degC | HVG %.1f degC\n', ...
    th_dT_motor, th_dT_PPS, th_dT_HVG);
fprintf('    Op limit : %.0f-%.0f degC abs  (dT limit %.0f degC above %d degC ambient)\n', ...
    rogue.T_op_C(1), rogue.T_op_C(2), rogue.T_op_C(2) - rogue.th.T_ambient_C, rogue.th.T_ambient_C);
fprintf('    Cooldown to <1 degC:\n');
fprintf('      Motor : %.0f s (%.1f min)  [tau = %.0f s]\n', t_cool_motor_s, t_cool_motor_s/60, rogue.th.tau_motor_s);
fprintf('      PPS   : %.0f s (%.1f min)  [tau = %.0f s]\n', t_cool_PPS_s,   t_cool_PPS_s/60,   rogue.th.tau_PPS_fast_s);
fprintf('      HVG   : %.0f s (%.1f min)  [tau = %.0f s]\n', t_cool_HVG_s,   t_cool_HVG_s/60,   rogue.th.tau_HVG_fast_s);
if th_scale > 1
    fprintf('    ** Scaled peak dT: linear extrapolation only. 20 s FEM not yet available.\n');
    fprintf('    ** Time constants assumed invariant with burst duration.\n');
end

fprintf('\n  Recharge vs motor cooldown margin:\n');
fprintf('  %10s | %12s | %15s | %12s\n', 'P_RTG [We]', 'Rchg [s]', 'Motor cool [s]', 'Margin [s]');
div();
for p = 1:numel(NEP.params.cfg.P_RTG_cases_We)
    P_case   = NEP.params.cfg.P_RTG_cases_We(p);
    t_rchg   = th_r.t_recharge_s(p);
    margin   = t_rchg - t_cool_motor_s;
    tag = '';
    if margin < 0
        tag = sprintf('  ** FAIL: motor not cooled by recharge end (%.0f s short)', abs(margin));
    end
    fprintf('  %10.1f | %12.0f | %15.0f | %12.0f%s\n', P_case, t_rchg, t_cool_motor_s, margin, tag);
end
fprintf('  Note: FEM characterised single burst only. Negative margin means thermal\n');
fprintf('  accumulation on successive cycles; steady-state peak must be confirmed\n');
fprintf('  below 50 degC absolute and 40 degC interface limit before clearing ops.\n');

%% ── 13. MASS BUDGET ────────────────────────────────────────────────────
sec('13. MASS BUDGET');
fprintf('\n  %-20s  %s\n', 'Component', 'Mass');
div();
fprintf('  %-20s  %.2f kg\n', 'RTG',   NEP.mass.rtg_kg);
fprintf('  %-20s  %.2f kg\n', 'Rogue', NEP.mass.rogue_kg);
fprintf('  %-20s  pending (~1-2 kg)\n', 'MPPT + coupling');
div();
fprintf('  %-20s  %.2f kg lower bound\n', 'System total', NEP.mass.total_kg);

fprintf('\n  Propulsion-system fraction by spacecraft mass:\n\n');
fprintf('  %8s | %10s | %13s\n', 'S/C [kg]', 'Payload[kg]', 'Prop frac [%]');
div();
for i = 1:numel(cfg.m_sc_kg)
    fprintf('  %8.0f | %10.1f | %13.1f\n', cfg.m_sc_kg(i), ...
        max(0, cfg.m_sc_kg(i) - cfg.m_prop_sys_kg), cfg.m_prop_sys_kg/cfg.m_sc_kg(i)*100);
end

%% ── 14. TORQUE ANALYSIS ────────────────────────────────────────────────
sec('14. TORQUE ANALYSIS');
if ~NEP.torque.computed
    fprintf('\n  Gated. Set cfg.rogue_origin_in_RTG_m once mounting configuration is defined.\n');
    fprintf('  RTG CoM (RTG frame):     [0, 0, 106.5] mm\n');
    fprintf('  Rogue CoM (Rogue frame): [50.5, 147.2, 47.5] mm\n');
else
    alpha_deg_s2 = rad2deg(NEP.torque.alpha_mag_rads2);
    fprintf('\n  Torque arm:      %.2f mm\n', NEP.torque.arm_mm);
    fprintf('  |tau|:           %.3e N.m\n', NEP.torque.tau_mag_Nm);
    fprintf('  Angular accel:   %.3e deg/s^2\n', alpha_deg_s2);
    fprintf('  Drift per burst: %.3f deg\n', NEP.torque.drift_deg);
    fprintf('  Angular impulse: %.3e N.m.s per pulse\n', NEP.torque.ang_impulse_Nms);
end

%% ── 15. FAMILY FEASIBILITY SCREEN ──────────────────────────────────────
sec('15. FAMILY FEASIBILITY SCREEN');
fprintf('\n  Profiles closed by total impulse (I_delivered >= I_req).\n');
fprintf('  n_RTG omitted (orthogonal). Confirmed Rogue: I_del = I_bit x N.\n');
fprintf('  Public-spec variants: I_del fixed at the I_total spec (rows constant\n');
fprintf('  across pulse columns; spec pulse count = cfg.n_pulses_at_spec).\n\n');

if has_ep
    I_req_all = arrayfun(@(x) x.I_total_req_Ns, ep);
    n_all_ep  = numel(ep);
    prof_src  = sprintf('%d profiles (Extended_Profiles)', n_all_ep);
else
    I_req_all = arrayfun(@(p) ...
        p.m_sc_kg * (1 - exp(-p.dV_req_ms / (rogue.Isp_s * g0))) * rogue.Isp_s * g0, NEP.mp);
    n_all_ep  = numel(NEP.mp);
    prof_src  = sprintf('%d profiles (core model)', n_all_ep);
end
fprintf('  Profile set: %s\n\n', prof_src);

n_pulse_cols = [1e6, 10e6, 50e6];
col_hdrs     = {'1M pulses', '10M pulses', '50M pulses'};

cfg_list = {};
cfg_list{end+1} = {'Rogue conf. x1',   @(N) rogue.I_bit_Ns * 1 * N};
cfg_list{end+1} = {'Rogue conf. x3',   @(N) rogue.I_bit_Ns * 3 * N};
cfg_list{end+1} = {'Rogue conf. x5',   @(N) rogue.I_bit_Ns * 5 * N};
% Spec-fixed configs deliver their public I_total regardless of the pulse
% column (toolkit convention; spec pulse count = cfg.n_pulses_at_spec).
if has_RP, cfg_list{end+1} = {'Rogue public x1', @(N) NEP_RP.I_total_Ns}; end
if has_W,  cfg_list{end+1} = {'Warlock x1',      @(N) NEP_W.I_total_Ns};  end
if has_SM, cfg_list{end+1} = {'SuperMagdrive x1',@(N) NEP_SM.I_total_Ns}; end
n_cfg = numel(cfg_list);

fprintf('  %-24s |', 'Configuration');
for c = 1:numel(n_pulse_cols), fprintf(' %-14s |', col_hdrs{c}); end
fprintf('\n  %s\n', repmat('-', 1, 26 + numel(n_pulse_cols) * 17));

for r = 1:n_cfg
    lbl  = cfg_list{r}{1};
    I_fn = cfg_list{r}{2};
    fprintf('  %-24s |', lbl);
    for c = 1:numel(n_pulse_cols)
        I_del    = I_fn(n_pulse_cols(c));
        n_closed = sum(I_del >= I_req_all);
        fprintf('  %2d / %-2d         |', n_closed, n_all_ep);
    end
    fprintf('\n');
    if r == 3, fprintf('  %s\n', repmat('-', 1, 26 + numel(n_pulse_cols) * 17)); end
end

fprintf('\n  I_bit derivation gap:\n');
if has_RP
    fprintf('    Rogue:         %4.0f uN.s -> %4.0f uN.s  (%.0fx)\n', ...
            rogue.I_bit_Ns*1e6, NEP_RP.cfg.I_bit_from_IT*1e6, NEP_RP.cfg.I_bit_from_IT/rogue.I_bit_Ns);
end
if has_W
    fprintf('    Warlock:       F_max/f %4.0f uN.s | I_total/10M %4.0f uN.s  (%.0fx)\n', ...
            NEP_W.cfg.I_bit_from_F*1e6, NEP_W.cfg.I_bit_from_IT*1e6, ...
            NEP_W.cfg.I_bit_from_IT/NEP_W.cfg.I_bit_from_F);
end
if has_SM
    fprintf('    SuperMagdrive: F_max/f %4.0f uN.s | I_total/10M %5.0f uN.s  (%.0fx)\n', ...
            NEP_SM.cfg.I_bit_from_F*1e6, NEP_SM.cfg.I_bit_from_IT*1e6, ...
            NEP_SM.cfg.I_bit_from_IT/NEP_SM.cfg.I_bit_from_F);
end
if ~has_RP && ~has_W && ~has_SM
    fprintf('    Run Rogue_Public, Warlock, SuperMag for gap analysis.\n');
end

%% ── 16. MAGDRIVE FAMILY DEEP DIVES ────────────────────────────────────
sec('16. MAGDRIVE FAMILY DEEP DIVES');

if has_RP || has_W || has_SM
    fprintf('\n  Operating-point grids, charge-side eta sweep, and head-mass band.\n');
    fprintf('  Run variant scripts to populate missing sections.\n');
end

% ── Rogue Public ──────────────────────────────────────────────────────
if has_RP
    fprintf('\n  %s\n  --- ROGUE 3 (PUBLIC SPEC) ---\n  %s\n', ...
        repmat('-',1,68), repmat('-',1,68));
    show_dv_grid(NEP_RP.grid, 1, 'kg');

    fprintf('\n  Rogue Public eta_charge sweep (m_sc %.0f kg, default power):\n', NEP_RP.sweep.m_sc_kg);
    fprintf('    (lifetime dV is impulse-limited and invariant in eta_charge)\n');
    fprintf('    %5s | %8s | %10s | %8s | %12s\n', ...
        'eta', 'P_net[W]', 'rchg[min]', 'duty[%]', 'Mpulse/yr');
    fprintf('    %s\n', repmat('-', 1, 56));
    for k = 1:numel(NEP_RP.sweep.eta_charge)
        fprintf('    %5.2f | %8.2f | %10.1f | %8.2f | %12.1f\n', ...
            NEP_RP.sweep.eta_charge(k), NEP_RP.sweep.P_net_W(k), ...
            NEP_RP.sweep.rchg_min(k), NEP_RP.sweep.duty_pct(k), ...
            NEP_RP.sweep.pulses_per_yr_M(k));
    end

    fprintf('\n  Rogue Public specific mass (head +/-%.0f%%):\n', NEP_RP.unc.frac*100);
    fprintf('    %-14s | %8s | %8s | %8s | %12s | %12s\n', ...
        'Power option', 'lo[kg]', 'nom[kg]', 'hi[kg]', 'alpha_lo', 'alpha_hi');
    fprintf('    %s\n', repmat('-', 1, 72));
    rp_lbl = {'RTG', 'RTG+'};
    for p = 1:numel(NEP_RP.unc.m_sys_nom_kg)
        fprintf('    %-14s | %8.2f | %8.2f | %8.2f | %9.2f kg/We | %9.2f kg/We\n', ...
            rp_lbl{p}, NEP_RP.unc.m_sys_lo_kg(p), NEP_RP.unc.m_sys_nom_kg(p), ...
            NEP_RP.unc.m_sys_hi_kg(p), ...
            NEP_RP.unc.alpha_lo_kgWe(p), NEP_RP.unc.alpha_hi_kgWe(p));
    end
end

% ── Warlock ───────────────────────────────────────────────────────────
if has_W
    fprintf('\n  %s\n  --- WARLOCK ---\n  %s\n', ...
        repmat('-',1,68), repmat('-',1,68));
    fprintf('  Default power: RTG+  (best single-unit option; duty %.2f%%)\n', ...
        NEP_W.ops.duty_pct);
    show_dv_grid(NEP_W.grid, 4, 'kg');

    fprintf('\n  Warlock operating point by power option:\n');
    fprintf('    %-14s | %8s | %10s | %8s | %10s\n', ...
        'Power option', 'P_net[W]', 'rchg[min]', 'duty[%]', 'dV_10M[m/s]');
    fprintf('    %s\n', repmat('-',1,60));
    w_ops   = {NEP_W.ops_rtg, NEP_W.ops_rtg_plus, NEP_W.ops_rsg35, NEP_W.ops_rsg100};
    w_lbl   = {'RTG', 'RTG+ [default]', 'RSG-35', 'RSG-100'};
    for p = 1:numel(w_ops)
        fprintf('    %-14s | %8.2f | %10.1f | %8.2f | %10s\n', ...
            w_lbl{p}, w_ops{p}.P_net_W, w_ops{p}.rchg_min, w_ops{p}.duty_pct, ...
            fmt_dv(w_ops{p}.dV_10M_ms));
    end

    fprintf('\n  Warlock eta_charge sweep (m_sc %.0f kg, default power):\n', NEP_W.sweep.m_sc_kg);
    fprintf('    (lifetime dV is impulse-limited and invariant in eta_charge)\n');
    fprintf('    %5s | %8s | %10s | %8s | %12s\n', ...
        'eta', 'P_net[W]', 'rchg[min]', 'duty[%]', 'Mpulse/yr');
    fprintf('    %s\n', repmat('-', 1, 56));
    for k = 1:numel(NEP_W.sweep.eta_charge)
        fprintf('    %5.2f | %8.2f | %10.1f | %8.2f | %12.1f\n', ...
            NEP_W.sweep.eta_charge(k), NEP_W.sweep.P_net_W(k), ...
            NEP_W.sweep.rchg_min(k), NEP_W.sweep.duty_pct(k), ...
            NEP_W.sweep.pulses_per_yr_M(k));
    end

    fprintf('\n  Warlock specific mass (head +/-%.0f%%):\n', NEP_W.unc.frac*100);
    fprintf('    %-14s | %8s | %8s | %8s | %12s | %12s\n', ...
        'Power option', 'lo[kg]', 'nom[kg]', 'hi[kg]', 'alpha_lo', 'alpha_hi');
    fprintf('    %s\n', repmat('-', 1, 72));
    w_lbl2 = {'RTG', 'RSG-35', 'RSG-100', 'RTG+'};
    for p = 1:numel(NEP_W.unc.m_sys_nom_kg)
        fprintf('    %-14s | %8.2f | %8.2f | %8.2f | %9.2f kg/We | %9.2f kg/We\n', ...
            w_lbl2{p}, NEP_W.unc.m_sys_lo_kg(p), NEP_W.unc.m_sys_nom_kg(p), ...
            NEP_W.unc.m_sys_hi_kg(p), ...
            NEP_W.unc.alpha_lo_kgWe(p), NEP_W.unc.alpha_hi_kgWe(p));
    end
end

% ── SuperMagdrive ──────────────────────────────────────────────────────
if has_SM
    fprintf('\n  %s\n  --- SUPERMAGDRIVE ---\n  %s\n', ...
        repmat('-',1,68), repmat('-',1,68));
    fprintf('  Default power: RSG-200  (RTG/RTG+ infeasible at this scale; duty <0.1%%)\n');
    show_dv_grid(NEP_SM.grid, 5, 'kg');

    fprintf('\n  SuperMagdrive eta_charge sweep (m_sc %.0f kg, default power):\n', NEP_SM.sweep.m_sc_kg);
    fprintf('    (lifetime dV is impulse-limited and invariant in eta_charge)\n');
    fprintf('    %5s | %8s | %10s | %8s | %12s\n', ...
        'eta', 'P_net[W]', 'rchg[min]', 'duty[%]', 'Mpulse/yr');
    fprintf('    %s\n', repmat('-', 1, 56));
    for k = 1:numel(NEP_SM.sweep.eta_charge)
        fprintf('    %5.2f | %8.2f | %10.1f | %8.2f | %12.1f\n', ...
            NEP_SM.sweep.eta_charge(k), NEP_SM.sweep.P_net_W(k), ...
            NEP_SM.sweep.rchg_min(k), NEP_SM.sweep.duty_pct(k), ...
            NEP_SM.sweep.pulses_per_yr_M(k));
    end

    fprintf('\n  SuperMagdrive specific mass (head +/-%.0f%%):\n', NEP_SM.unc.frac*100);
    fprintf('    %-14s | %8s | %8s | %8s | %12s | %12s\n', ...
        'Power option', 'lo[kg]', 'nom[kg]', 'hi[kg]', 'alpha_lo', 'alpha_hi');
    fprintf('    %s\n', repmat('-', 1, 72));
    sm_lbl = {'RTG', 'RTG+', 'RSG-35', 'RSG-100', 'RSG-200 [default]'};
    for p = 1:numel(NEP_SM.unc.m_sys_nom_kg)
        fprintf('    %-18s | %8.2f | %8.2f | %8.2f | %9.2f kg/We | %9.2f kg/We\n', ...
            sm_lbl{p}, NEP_SM.unc.m_sys_lo_kg(p), NEP_SM.unc.m_sys_nom_kg(p), ...
            NEP_SM.unc.m_sys_hi_kg(p), ...
            NEP_SM.unc.alpha_lo_kgWe(p), NEP_SM.unc.alpha_hi_kgWe(p));
    end
end

if ~has_RP && ~has_W && ~has_SM
    fprintf('\n  Run Rogue_Public, Warlock, and/or SuperMag scripts to populate this section.\n');
end

fprintf('\nMicroNEP_Summary complete.\n');

%% ── LOCAL FUNCTIONS ────────────────────────────────────────────────────

function dV = dv_life(I_bit, n_pulses, m_sc, m_sys, Isp, g0)
% Mirrors MicroNEP_Model.m's delta_v_lifetime (MATLAB scoping). The
% propellant-overrun case returns NaN (infeasible), matching Model.
    if m_sc <= m_sys, dV = NaN; return; end
    m_p = I_bit * n_pulses / (Isp * g0);
    if m_p >= m_sc - m_sys, dV = NaN; return; end
    dV = Isp * g0 * log(m_sc / (m_sc - m_p));
end

function s = fmt_dv(v)
    if isnan(v),     s = 'N/A';
    elseif isinf(v), s = '>prop';
    else,            s = sprintf('%.2f', v);
    end
end

function s = okflag(tf)
    if tf, s = 'OK'; else, s = '** BELOW LIMIT'; end
end

function s = conditional(tf, yes, no)
    if tf, s = yes; else, s = no; end
end

function show_dv_grid(grid, p_idx, mass_unit)
% Compact print of an architecture grid for the chosen power-option index.
    fprintf('  dV [m/s] grid  (%s):\n', grid.label{p_idx});
    fprintf('    %-12s |', sprintf('m_sc [%s]', mass_unit));
    for c = 1:numel(grid.N_pulses)
        fprintf(' %9s', sprintf('%.0fM', grid.N_pulses(c)/1e6));
    end
    fprintf('\n    %s\n', repmat('-', 1, 14 + 10*numel(grid.N_pulses)));
    dvg = grid.dV_ms{p_idx};
    for r = 1:numel(grid.m_sc_kg)
        fprintf('    %-12.0f |', grid.m_sc_kg(r));
        for c = 1:numel(grid.N_pulses)
            v = dvg(r,c);
            if isnan(v), fprintf(' %9s', 'N/A');
            elseif v >= 1e4, fprintf(' %9.0f', v);
            else,            fprintf(' %9.1f', v); end
        end
        fprintf('\n');
    end
    clg = grid.cal_life_yr{p_idx};
    cal_row = find(any(~isnan(clg), 2), 1, 'last');
    if isempty(cal_row), cal_row = 1; end
    fprintf('    %-12s |', 'cal life [yr]');
    for c = 1:numel(grid.N_pulses)
        v = clg(cal_row, c);
        if isnan(v), fprintf(' %9s', 'N/A');
        else,        fprintf(' %9.2f', v); end
    end
    fprintf('\n');
end