%% =========================================================================
%% MicroNEP_Params.m — System Parameters and Configuration
%% =========================================================================
% Single source of truth for the Magdrive Rogue + Perpetual Atomics Am-RTG
% micro-NEP system. Hardware inputs and sweep ranges only — all derived
% quantities are computed in MicroNEP_Model.m.
%
% Run order (canonical; mirrored in MicroNEP_Run_All.m):
%   1.  MicroNEP_Params.m
%   2.  MicroNEP_Model.m              -> NEP
%   3.  MicroNEP_Rogue_Public.m       -> NEP_RP
%   4.  MicroNEP_Warlock.m            -> NEP_W
%   5.  MicroNEP_SuperMag.m           -> NEP_SM
%   6.  MicroNEP_Extended_Profiles.m  -> EXT, ep   (before Family_Compare:
%                                        populates ep for Tables 4/4a/4b)
%   7.  MicroNEP_Family_Compare.m     -> family
%   8.  MicroNEP_Deep_Dives.m         -> dd
%   9.  MicroNEP_Plots.m              (optional)
%   10. MicroNEP_Thermal_Plots.m      (optional; before Summary -> s12
%                                      reports burst-scaled thermals)
%   11. MicroNEP_Summary.m
% Steps 3-5 each call MicroNEP_Variant_Core.m internally (shared function,
% not a pipeline stage in its own right).

clear; clc; close all;

%% ── A) PHYSICAL CONSTANTS ───────────────────────────────────────────────
g0    = 9.80665;          % standard gravity [m/s^2]
sigma = 5.670374419e-8;   % Stefan-Boltzmann constant [W/m^2/K^4]

%% ── B) TEG CHARACTERISATION (UL-RTG-IS-0001 Table 4-5) ──────────────────
%   T_set | T_cold | dT    | V    | I    | P_max | eta  | R_th
%   [degC]| [degC] | [degC]| [V]  | [A]  | [W]   | [%]  | [degC/W]
teg_data = [
     5,  18.08, 189.70, 4.31, 0.28, 1.20, 4.00, 6.32;
     0,  14.11, 190.90, 4.32, 0.29, 1.25, 4.15, 6.33;
    -5,  10.62, 196.30, 4.44, 0.30, 1.32, 4.40, 6.54;
   -10,   6.67, 197.50, 4.56, 0.30, 1.37, 4.50, 6.58;
   -20,  -0.27, 202.18, 4.65, 0.31, 1.44, 4.80, 6.73;
];
teg.T_set_C   = teg_data(:,1);  teg.T_cold_C  = teg_data(:,2);
teg.delta_T_C = teg_data(:,3);  teg.V_V       = teg_data(:,4);
teg.I_A       = teg_data(:,5);  teg.P_max_W   = teg_data(:,6);
teg.eta_pct   = teg_data(:,7);  teg.R_th_CW   = teg_data(:,8);

%% ── C) RTG (baseline) ───────────────────────────────────────────────────
rtg.n_TEG         = 6;
rtg.P_lab_min_W   = 7.2;
rtg.P_lab_max_W   = 8.6;
rtg.P_design_W    = 10;      % cold-space, optimised TEGs
rtg.V_max_V       = 28;
rtg.P_parasitic_W = 0.010;
rtg.T_housing_C   = 25;
rtg.max_stack     = 5;       % mechanical stacking limit (50 We ceiling)

rtg.mass_kg            = 12.5;
rtg.specific_mass_kgWe = rtg.mass_kg / rtg.P_design_W;
rtg.CoM_m              = [0, 0, 0.1065];
rtg.Ixx_kgm2 = 0.0655;  rtg.Iyy_kgm2 = 0.0655;  rtg.Izz_kgm2 = 0.0745;
rtg.emissivity         = 0.92;       % matte black paint
rtg.A_radiate_m2       = 0.638786;   % fin radiating area
rtg.A_conduct_m2       = 0.066058;   % total conducting area (both faces)

% Thermal limits (ICD Table 2-1). Viton -30 degC is a ground constraint;
% O-rings vent at launch.
rtg.T_viton_C    = [-30, 200];
rtg.T_lemo_C     = [-55, 250];
rtg.T_adhesive_C = [-70, 200];

%% ── D) RTG+ ───────────────────────
% PA Am-241 RTG+ in the same mechanical envelope as the baseline RTG.
rtg_plus.P_design_W    = 40;        % ~20% efficiency gain on same form factor
rtg_plus.mass_kg       = 12.5;      % same mechanical envelope
rtg_plus.specific_mass_kgWe = rtg_plus.mass_kg / rtg_plus.P_design_W;
rtg_plus.label         = 'PA RTG+';
rtg_plus.confirmed     = false;     % direction confirmed; output pending test

%% ── D2) RSG — Radioisotope Stirling Generators ───────────────────────────
% PA Stirling convertor array: ~4x higher efficiency than thermoelectric RTG.
% RSG-35 and RSG-100 are engineering estimates; RSG-200 confirmed via Mesalam
% et al. (2024) Fig 2 / Table 7-8 and NASA Glenn collaboration (IBFP).
% Note: RSG P_design_W is the *electrical* output; MPPT still applies.
rsg(1).label              = 'PA RSG-35';
rsg(1).P_design_W         = 35;
rsg(1).mass_kg            = 22.5;
rsg(1).specific_mass_kgWe = rsg(1).mass_kg / rsg(1).P_design_W;
rsg(1).confirmed          = false;    % engineering estimate

rsg(2).label              = 'PA RSG-100';
rsg(2).P_design_W         = 100;
rsg(2).mass_kg            = 75.0;
rsg(2).specific_mass_kgWe = rsg(2).mass_kg / rsg(2).P_design_W;
rsg(2).confirmed          = false;

rsg(3).label              = 'PA RSG-200';
rsg(3).P_design_W         = 200;
rsg(3).mass_kg            = 110.0;
rsg(3).specific_mass_kgWe = rsg(3).mass_kg / rsg(3).P_design_W;
rsg(3).confirmed          = true;     % Mesalam 2024 confirmed

%% ── E) EM HEATER (substitutes for Am-241 in engineering-model phase) ────
% 66.6 W thermal in -> ~10 We electrical + ~56.6 W rejected via fins.
heater.P_W = 66.6;  heater.V_V = 24.4;  heater.I_A = 2.7;  heater.R_ohm = 9.0;

%% ── F) MPPT / PMS ───────────────────────────────────────────────────────
mppt.eta     = 0.92;
mppt.V_out_V = 28;

%% ── G) ROGUE ────────────────────────────────────────────────────────────
rogue.V_range_V   = [24, 29.4];
rogue.V_nominal_V = 28;

% Energy storage (10 kJ full, 8 kJ accessible).
rogue.E_store_J      = 8000;
rogue.E_store_full_J = 10000;

% Pulse parameters. Burst can be extended by reducing f:
%   t_burst_max_s = E_store / (E_pulse * f).
% Single-pulse operation is supported.
rogue.E_per_pulse_J = 4.0;
rogue.f_Hz          = 100;
rogue.t_burst_max_s = rogue.E_store_J / (rogue.E_per_pulse_J * rogue.f_Hz);

% Specific impulse. ICD/NSIP baseline 1500 s; public range 1800-3500 s.
% 1800 s accepted for parametric study.
rogue.Isp_s         = 1800;
rogue.Isp_website_s = [1800, 3500];

% PPU chain efficiencies (IES -> HVG -> PPS -> plasma coupling).
rogue.eta_IES    = 0.80;
rogue.eta_HVG    = 0.90;
rogue.eta_PPS    = 0.60;
rogue.eta_plasma = 0.20;
rogue.eta_chain  = rogue.eta_IES * rogue.eta_HVG * rogue.eta_PPS * rogue.eta_plasma;

rogue.F_ICD_range_N = [1e-3, 5e-3];   % ICD thrust range, reference only

% Impulse bit. Sweep range covers the propellant-mass-implied upper bound
% and public spec figures.
rogue.I_bit_Ns     = 12e-6;
rogue.I_bit_min_Ns = 10e-6;
rogue.I_bit_max_Ns = 20e-6;

% Thrust-to-power: T/P = I_bit / E_pulse (frequency cancels). Units: mN/kW.
% Reference values: ion 30-40, Hall 50-70, PTFE-PPT 5-13.
rogue.T_per_P_mNkW = rogue.I_bit_Ns / rogue.E_per_pulse_J * 1e6;

rogue.m_prop_kg = 0.200;  % propellant load [kg]

% PPU electrical interface. Firmware charge range is 3-10 A; RTG-limited
% operation requires <=0.33 A and a sub-3 A configuration.
rogue.V_PPU_V        = 28;
rogue.I_charge_max_A = 10.0;

% Operational limits and pulse budget (confirmed Rogue hardware).
% Variant pulse capabilities are NOT stored here: the public-spec, Warlock,
% and SuperMagdrive total-impulse ceilings are public-spec figures, so each
% variant script derives its spec-equivalent pulse count as
%   n_pulses_at_spec = I_total_spec / I_bit
% (e.g. Rogue public: 3000 Ns / 100 uN.s = 30M pulses).
rogue.T_op_C            = [0, 50];
rogue.T_mount_max_C     = 40;
rogue.n_pulses_design   = 1e6;
rogue.n_pulses_ambition = 10e6;             % Rogue confirmed

% Mechanical (Rogue 3 Mechanical ICD Rev A).
rogue.mass_dry_kg   = 2.95;
rogue.mass_kg       = 3.05;
rogue.CoM_m         = [0.05048, 0.14715, 0.0475];   % +/- 3 mm
rogue.dim_m         = [0.300, 0.240, 0.200];
rogue.thrust_vec    = [0 1 0];
rogue.inertia_kgmm2 = [21245.9, 246.58, 21276.8];
rogue.inertia_kgm2  = rogue.inertia_kgmm2 * 1e-6;

%% ── H) ROGUE THERMAL DATA (Exotrail FEM, 10 s burst at 100 Hz, 4 J/pulse)
% Single-burst FEM only; extended bursts and RTG conduction not characterised.

% External wall.
rogue.th.dT_hotwall_C     = 1.953;   % at t = 10 s (burst end)
rogue.th.dT_hwpeak_C      = 2.832;   % peak at t = 17.25 s (post-burn)
rogue.th.dT_hotwall_avg_C = 0.194;   % spatial average at t = 10 s
rogue.th.dT_coldwall_C    = 1.10;    % peak at t ~ 47 s
rogue.th.t_hwpeak_s       = 17.25;

% Internal components: dT_X_C at t = 10 s; dT_X_pk_C at peak.
rogue.th.dT_PPS_C        = 19.667;  rogue.th.dT_PPS_pk_C   = 19.667;
rogue.th.dT_motor_C      = 21.656;  rogue.th.dT_motor_pk_C = 22.516;
rogue.th.dT_HVG_C        = 16.218;  rogue.th.dT_HVG_pk_C   = 16.462;
rogue.th.dT_motor_200s_C = 9.32;

% Decay time constants (log-linear fits to FEM post-peak).
rogue.th.tau_motor_s    = 211.0;
rogue.th.tau_PPS_fast_s =  70.6;   rogue.th.tau_PPS_slow_s = 101.2;
rogue.th.tau_HVG_fast_s = 101.3;   rogue.th.tau_HVG_slow_s = 101.3;
rogue.th.tau_hw_max_s   = 129.3;
rogue.th.tau_cw_max_s   = 396.4;

% Internal dT at the hot-wall peak (t = 17.25 s) for casing energy balance.
rogue.th.dT_PPS_at_hwpeak_C   = 10.875;
rogue.th.dT_motor_at_hwpeak_C = 21.504;
rogue.th.dT_HVG_at_hwpeak_C   = 14.645;

% Internal heat budget (TCU excluded -> total is a lower bound).
rogue.th.P_internal_W = 97.16;   rogue.th.E_internal_J = 971.6;
rogue.th.P_PPS_W      = 54.0;
rogue.th.P_motor_W    = 26.76;
rogue.th.P_HVG_W      = 9.52;

% Geometry and material properties for radiation and capacitance estimates.
rogue.th.A_walls_m2    = 4 * 0.01;   % four 100 x 100 mm external walls
rogue.th.emissivity    = 0.80;       % anodised Al estimate
rogue.th.T_ambient_C   = 20;         % lab reference
rogue.th.c_p_Al_JkgK   = 900;
rogue.th.c_p_elec_JkgK = 500;        % mixed electronics estimate

%% ── I) SWEEP CONFIGURATION ──────────────────────────────────────────────
cfg.mission_days  = 365;
cfg.mission_years = cfg.mission_days / 365.25;

% Spacecraft mass sweep and reference.
cfg.m_sc_kg  = [25, 50, 100, 200];
cfg.m_ref_kg = 50;

% Propulsion-system mass lower bound (RTG + Rogue; MPPT and coupling pending).
cfg.m_prop_sys_kg = rtg.mass_kg + rogue.mass_kg;

% Propulsion-system mass fraction for specific-mass thresholds.
cfg.prop_mass_fraction_sweep = 0.1:0.1:0.8;
cfg.prop_mass_fraction_ref   = 0.30;
cfg.prop_mass_fraction_idx   = find(abs(cfg.prop_mass_fraction_sweep - cfg.prop_mass_fraction_ref) < 1e-9, 1);

% RTG power sweep and discrete cases.
cfg.P_RTG_sweep_W  = linspace(1, 50, 200);
cfg.P_RTG_cases_We = [rtg.P_lab_min_W, rtg.P_lab_max_W, rtg.P_design_W, rtg_plus.P_design_W];

% Operating-point sweeps.
cfg.E_store_sweep_J = [2000, 4000, 8000, 10000];
cfg.t_burst_s       = 20;
cfg.t_burst_sweep_s = [5, 10, 15, 20];
cfg.E_pulse_sweep_J = [0.5, 1.0, 2.0, 4.0];
% Frequency sweep extended to 1 kHz to cover future Rogue/Warlock operating range.
cfg.f_sweep_Hz      = [10, 25, 50, 100, 200, 500, 1000];

% Future high-f / low-E_pulse pairs: f [Hz] with concurrent E_pulse [J],
% scaled to hold average power (f * E_pulse) approximately constant at the
% 100 Hz / 4 J baseline (400 J/s). Scaling law for I_bit(E_pulse) uses the
% existing cfg.alpha_Ipulse. Values above 100 Hz are indicative pending
% Magdrive characterisation of the high-frequency regime.
cfg.f_future_pairs_Hz    = [10,   25,   50,  100,  200,  500, 1000];
cfg.f_future_Epulse_J    = [4.0,  4.0,  4.0,  4.0,  2.0,  0.8,  0.4];

% I_bit sweep covers the propellant-mass-implied upper bound.
cfg.I_bit_sweep_Ns = [10, 12, 25, 50, 100, 200, 300] * 1e-6;

% Pulse budget sweep for the N_pulses x I_bit capability map.
cfg.N_pulses_sweep = logspace(5, 9, 100);

% E_pulse -> I_bit scaling: I_bit = I_bit_ref * (E_pulse/E_pulse_ref)^alpha.
% alpha = 0.5 (feed-saturated), 0.7 (literature midpoint), 1.0 (linear).
cfg.alpha_Ipulse  = 0.7;
cfg.alpha_sweep   = [0.5, 0.7, 1.0];
cfg.E_pulse_ref_J = rogue.E_per_pulse_J;

% Stacking grid (n_rogue x n_rtg).
cfg.n_stk_max     = 5;
cfg.m_sc_stack_kg = [50, 300, 1000];

% Isp sensitivity sweep (1000 s included as lower-bound context only).
cfg.Isp_sweep_s = [150, 500, 1000, 1500, 1800, 2500, 3500];

% Total-impulse requirement for each tier of mission profiles.
cfg.req_tiers_Ns    = [150, 500, 2500];
cfg.req_tier_labels = {'Tier 1: Demo', 'Tier 2: Operational', 'Tier 3: Competitive'};
cfg.req_tier_colors = {[0.2 0.7 0.3], [0.9 0.6 0.1], [0.8 0.2 0.2]};

%% ── J) TORQUE GATING ────────────────────────────────────────────────────
% Set once mounting configuration is defined.
cfg.rogue_origin_in_RTG_m = [NaN, NaN, NaN];

%% ── K) SPECIFIC-MASS BENCHMARK LADDER ───────────────────────────────────
% Reference specific masses spanning radioisotope and reactor architectures.
% Values are alpha (kg/We); class distinguishes the family.
%
% Sources:
%   PA Am-241 RTG       : confirmed engineering model
%   PA Am-241 RTG+      : PA direction confirmed; output pending characterisation
%   ESA Am-241 (lunar)  : Ambrosi 2019; Mesalam 2024 (~1.0-1.4 W/kg)
%   MMRTG               : NASA/DOE; 125 We at 2.8 W/kg
%   GPHS-RTG            : NASA/DOE; 290 We at 5.2 W/kg (Cassini, Galileo)
%   PA RSG (Stirling)   : Mesalam 2024 Fig 2 / Table 7-8 (RSG-35 est.; RSG-200 confirmed)
%   ASRG concept        : Lockheed/Infinia; ~140 We at ~7-8 W/kg
%   Kilopower 1 kWe     : NASA STMD KRUSTY-derived
%   Kilopower 10 kWe    : NASA STMD high-end projection
%   NEP achievable      : Turyshev SGL 2026 baseline (10-20 kg/kWe)
%   NEP aggressive      : Turyshev SGL 2026 sub-20yr regime (~3 kg/kWe)
%   JIMO-class fission  : Prometheus/JIMO-class historical concept

bench.label = {'PA RTG', ...
               'PA RTG+', ...
               'ESA RTG (Am-241)', ...
               'MMRTG (Pu-238)', ...
               'GPHS-RTG (Pu-238)', ...
               'PA RSG-35', ...
               'ASRG (concept)', ...
               'Kilopower 1 kWe', ...
               'Kilopower 10 kWe', ...
               'NEP achievable (SGL)', ...
               'NEP aggressive (SGL)', ...
               'JIMO-class fission'};
bench.alpha_kgWe = [rtg.specific_mass_kgWe, rtg_plus.specific_mass_kgWe, 0.72, 0.36, 0.19, ...
                    rsg(1).specific_mass_kgWe, 0.13, ...
                    0.40, 0.10, 0.010, 0.003, 0.030];
bench.P_e_W      = [10,   rtg_plus.P_design_W,          14,   125,  290,  35,   140, ...
                    1000, 10000, 3e5, 3e5, 2e5];
bench.class      = {'RTG','RTG','RTG','RTG','RTG','RSG','RSG', ...
                    'Reactor','Reactor','Reactor','Reactor','Reactor'};
bench.confirmed  = [true, false, false, true, true, false, false, ...
                    false, false, false, false, false];

%% ── L) ROGUE PMAD / PPU SUB-ALLOCATION ──────────────────────────────────
rogue.alloc.head_kg     = 1.40;
rogue.alloc.ppu_kg      = 1.10;
rogue.alloc.store_kg    = 0.45;
rogue.alloc.harness_kg  = 0.10;
alloc_fields = fieldnames(rogue.alloc);
alloc_total  = sum(cellfun(@(f) rogue.alloc.(f), alloc_fields));
assert(abs(alloc_total - rogue.mass_kg) < 0.05, ...
       'Rogue mass allocation does not sum to mass_kg');

%% ── M) VALIDATION ───────────────────────────────────────────────────────
assert(rtg.P_lab_min_W < rtg.P_lab_max_W, 'RTG lab range inverted');
assert(rtg.P_lab_max_W <= rtg.P_design_W, 'RTG lab max exceeds design power');
assert(rogue.eta_chain > 0 && rogue.eta_chain < 1, 'PPU chain efficiency out of bounds');
assert(rogue.E_store_J <= rogue.E_store_full_J, 'Accessible store exceeds full store');
assert(abs(rogue.t_burst_max_s - 20) < 1e-9, 't_burst_max_s mismatch');
assert(rogue.I_bit_min_Ns <= rogue.I_bit_Ns && rogue.I_bit_Ns <= rogue.I_bit_max_Ns, ...
       'I_bit baseline outside min/max bracket');
assert(numel(bench.alpha_kgWe) == numel(bench.P_e_W) && ...
       numel(bench.label) == numel(bench.alpha_kgWe), 'Benchmark ladder length mismatch');
assert(~isempty(cfg.prop_mass_fraction_idx), 'Reference mass fraction not in sweep');
assert(rtg_plus.P_design_W > rtg.P_design_W, 'RTG+ should exceed baseline RTG power');

%% ── LOAD MESSAGE ────────────────────────────────────────────────────────
fprintf('MicroNEP_Params loaded.\n');
fprintf('  RTG    : %.0f We design  | %.1f kg  | %.2f kg/We\n', ...
    rtg.P_design_W, rtg.mass_kg, rtg.specific_mass_kgWe);
fprintf('  RTG+   : %.0f We design  | %.1f kg  | %.2f kg/We  [output pending characterisation]\n', ...
    rtg_plus.P_design_W, rtg_plus.mass_kg, rtg_plus.specific_mass_kgWe);
fprintf('  Rogue  : %.0f kJ store   | %.0f Hz  | %.1f J/pulse  | %.0f s burst  | %.2f kg\n', ...
    rogue.E_store_J/1e3, rogue.f_Hz, rogue.E_per_pulse_J, rogue.t_burst_max_s, rogue.mass_kg);
fprintf('  I_bit  : %.0f uN.s       | Isp %.0f s   | T/P %.1f mN/kW   | eta_chain %.1f%%\n', ...
    rogue.I_bit_Ns*1e6, rogue.Isp_s, rogue.T_per_P_mNkW, rogue.eta_chain*100);
fprintf('  RSG    : RSG-35  %3.0f We | %5.1f kg | %.2f kg/We  [est.]\n', ...
    rsg(1).P_design_W, rsg(1).mass_kg, rsg(1).specific_mass_kgWe);
fprintf('           RSG-100 %3.0f We | %5.1f kg | %.2f kg/We  [est.]\n', ...
    rsg(2).P_design_W, rsg(2).mass_kg, rsg(2).specific_mass_kgWe);
fprintf('           RSG-200 %3.0f We | %5.1f kg | %.2f kg/We  \n', ...
    rsg(3).P_design_W, rsg(3).mass_kg, rsg(3).specific_mass_kgWe);
fprintf('  Bench  : %d entries (%.3f - %.2f kg/We)  | f_prop sweep %.1f - %.1f (ref %.2f)\n', ...
    numel(bench.label), min(bench.alpha_kgWe), max(bench.alpha_kgWe), ...
    cfg.prop_mass_fraction_sweep(1), cfg.prop_mass_fraction_sweep(end), cfg.prop_mass_fraction_ref);
fprintf('  f sweep: [%s] Hz  | %d points \n', ...
    num2str(cfg.f_sweep_Hz, '%g '), numel(cfg.f_sweep_Hz));