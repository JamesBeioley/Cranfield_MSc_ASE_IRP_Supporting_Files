%% =========================================================================
%% MicroNEP_Model.m — Calculations and Parametric Sweeps
%% =========================================================================
% Computes all derived performance metrics for the Micro-NEP system from the
% parameters in MicroNEP_Params.m. Outputs are packaged into the NEP struct
% consumed by all downstream scripts.
%
% Tier 1 — core capability sweeps (primary results):
%   A) Preamble: TEG quantities, baseline thrust, design-point recharge
%   D) Lifetime dV vs N_pulses x I_bit (capability map)
%   E) Mission profile feasibility (dual-constraint)
%   F) N_pulses breakeven per profile
%   G) Requirements analysis
%   H) Specific mass framework (alphas, benchmarks, f_prop sweep, breakeven)
%   I) dV vs spacecraft mass
%   J) Stacking analysis (n_rogue x n_rtg)
%
% Tier 2 — parameter sweeps:
%   K) Frequency sweep (F = I_bit x f invariance)
%   L) E_pulse -> I_bit scaling (alpha sweep)
%   M) Small-store regime study
%   N) RTG power sensitivity
%   O) Lifetime grids (f x E_store; f x E_pulse)
%
% Tier 3 — system / integration context:
%   P) RTG fin thermal equilibrium
%   Q) Rogue thermal capacitance
%   R) Torque analysis (gated)
%   S) Mass budget
%   T) Package into NEP struct
%
% Physics: F = I_bit x f for fixed-capacitor PPT operation. Deliverable dV is
% bounded by min(duty-cycle ceiling, pulse-life ceiling).

if ~exist('rogue','var'), error('Run MicroNEP_Params.m first.'); end

spy = 365.25 * 86400;

%% ── A) PREAMBLE ─────────────────────────────────────────────────────────
% TEG derived quantities.
teg.P_total_W   = teg.P_max_W * rtg.n_TEG;
teg.V_series_V  = teg.V_V * rtg.n_TEG;
teg.V_3s2p_V    = teg.V_V * 3;
teg.I_3s2p_A    = teg.I_A * 2;
teg.R_elec_ohm  = teg.V_V ./ teg.I_A;
teg.Q_per_TEG_W = heater.P_W / rtg.n_TEG;

% Baseline thrust from impulse bit. F = I_bit x f.
rogue.F_baseline_N     = rogue.I_bit_Ns     * rogue.f_Hz;
rogue.F_baseline_min_N = rogue.I_bit_min_Ns * rogue.f_Hz;
rogue.F_baseline_max_N = rogue.I_bit_max_Ns * rogue.f_Hz;

% Maximum sustainable charge current from a single RTG.
mppt.I_max_A = (rtg.P_design_W * mppt.eta - rtg.P_parasitic_W) / mppt.V_out_V;

% Design-point recharge / duty cycle (10 We, 8 kJ store, 20 s burst).
rc_max = recharge(rtg.P_design_W, mppt.eta, rtg.P_parasitic_W, ...
                  rogue.E_store_J, rogue.t_burst_max_s);
pt = rc_max;

%% ── D) LIFETIME dV vs N_PULSES x I_BIT (capability map) ─────────────────
% Total lifetime dV from full pulse budget, evaluated at the reference mass.
% Result is invariant in frequency, store size, and duty cycle.
m_ref = cfg.m_ref_kg;

cap.m_ref_kg       = m_ref;
cap.n_pulses       = cfg.N_pulses_sweep;
cap.I_bit_lines_Ns = cfg.I_bit_sweep_Ns;   % single source: Params sweep
cap.dV_grid        = zeros(numel(cap.I_bit_lines_Ns), numel(cap.n_pulses));
for k = 1:numel(cap.I_bit_lines_Ns)
    for j = 1:numel(cap.n_pulses)
        dvL = delta_v_lifetime(cap.I_bit_lines_Ns(k), cap.n_pulses(j), ...
                               m_ref, cfg.m_prop_sys_kg, rogue.Isp_s, g0);
        cap.dV_grid(k,j) = dvL.dV_total_ms;
    end
end

cap.dV_1M_ms  = delta_v_lifetime(rogue.I_bit_Ns, rogue.n_pulses_design,   m_ref, cfg.m_prop_sys_kg, rogue.Isp_s, g0).dV_total_ms;
cap.dV_10M_ms = delta_v_lifetime(rogue.I_bit_Ns, rogue.n_pulses_ambition, m_ref, cfg.m_prop_sys_kg, rogue.Isp_s, g0).dV_total_ms;
dV_cap_10M_ms = cap.dV_10M_ms;

%% ── E) MISSION PROFILE FEASIBILITY (dual-constraint) ────────────────────
% Each profile is checked against both the duty-cycle ceiling and the pulse-life
% ceiling. Both must be satisfied. Duty ceiling uses the hardware maximum burst
% (20 s, 100 Hz).
%
% dV sources (verified against heritage / literature, Jun 2026):
%   VLEO drag:        GOCE (250-300 km); NRLMSISE-00; Crisp et al. 2020.
%                     dV/yr verified by first-principles drag: 72/207/627
%                     m/s/yr at 350/300/250 km for compact 100 kg bus.
%                     100 m/s/yr = upper-mid band (~340 km) design point;
%                     STRONGLY altitude- and solar-activity-dependent.
%   Asteroid:         Hayabusa2 / OSIRIS-REx; Scheeres et al. 2022. Closes
%                     on single Rogue at ~4.2M pulses (only demo-HW close).
%   Frozen lunar      Ely & Lieb 2006 (frozen-orbit base; evidence-based).
%   (incl. PSR):      PSR support = application layer (Mazarico 2011, conc.).
%                     MERGED from prior 'Frozen lunar' + 'PSR lunar ops'.
%                     MARGINAL: pulse-life@10M = 2.4 m/s vs 3 m/s req ->
%                     closes only with 3x1 stack (~12.5M pulses).
%   NRHO:             Zimovan/Howell/Davis 2017; CAPSTONE 2022. Published
%                     NRHO SK few-m/s/yr (ideal) to ~20 (with OD/exec err);
%                     10 m/s/yr = sound mid-budget.
%   L1/L2 halo SK:    JWST ~2.5 m/s/yr; Lissajous SK to ~7.4 m/s/yr (aggr.).
%                     3 m/s/yr reasonable for small halo sentinel.
%   Phobos:           Zamaro & Biggs 2016. 8 m/s = representative QSO-
%                     maintenance ESTIMATE (esc. vel. ~11 m/s), not a hard
%                     published budget. [flagged: defensible estimate]
%   GEO proximity     N-S SK ~50 m/s/yr (verified; Soop 1994). Inspector
%   (insp/guardian):  100 m/s/2yr & guardian 250 m/s/5yr = same 50 m/s/yr
%                     rate, same s/c class. MERGED; carried as a RANGE.
%                     Deep dive unpacks: (A) persistent free-flyer >=50
%                     m/s/yr + patrol; (B) docked sortie inspector (low
%                     total dV; degraded-asset / ISAM-ops inspection).
%   Icy moon:         Lara 2005; Paskowitz & Scheeres 2006; JUICE/Clipper.
%                     Frozen Europa orbits unstable (~200-day life -> active
%                     SK). RTG solves POWER (4% flux, eclipse, cell degrad.)
%                     but NOT radiation DOSE -- the dose problem drove the
%                     industry from orbiters to flyby (Clipper). RTG
%                     necessary-but-not-sufficient; shielding mass in trade.
%   SE-L1 sentinel:   CuSP (6U); SWFO-L1/SOLAR-1 in-situ suite; AuroraMag.
%                     Small operational node (~50 kg). Rate-trivial but
%                     LIFETIME-BOUND: 5-yr/15 m/s needs pulse-budget growth
%                     or Rogue-public I_bit (pull-through). NEW.
%   Apophis prox:     RAMSES (rendezvous = 1530 m/s, 36.6 kNs -> 12x over
%                     Rogue-pub: INFEASIBLE to fly TO Apophis). Feasible
%                     architecture = proximity/companion module deployed by
%                     a carrier (cf. RAMSES ConOps: 1-20 km hover boxes,
%                     15 km Sun-phase imaging). Closes only with Rogue-pub
%                     I_bit + RTG+; NOT on confirmed 2026 HW by 2028 launch.
%                     Aspirational NSIP pull-through, readiness gap stated.

profile_defs = {
%   Label                                          dV_req [m/s]  m_sc [kg]  Notes
    'VLEO drag comp.',                100,          100,       '100 m/s/yr ~340 km, 100 kg; altitude/solar-activity dependent (GOCE; NRLMSISE-00)';
    'Asteroid proximity ops',                         2,           25,       'SRP / irregular-gravity hover; Hayabusa2/OSIRIS-REx; only demo-HW close (~4.2M)';
    'Frozen lunar orbit',         3,           50,       'Near-polar frozen orbit (Ely&Lieb 2006); PSR support as application; marginal->3x1 stack';
    'NRHO / cislunar relay',                         10,           50,       'Annual SK; Zimovan 2017 / CAPSTONE 2022; 10 m/s/yr mid-budget';
    'L1/L2 halo orbit SK',                            3,          100,       'Small sentinel; JWST ~2.5 m/s/yr; Lissajous SK to ~7.4 m/s/yr';
    'Phobos proximity ops',                           8,           50,       'QSO-maintenance estimate vs irregular grav + Martian tidal trim (Zamaro&Biggs 2016)';
    'GEO co-orbital proximity',     250,           50,       'Range 100-250 m/s; N-S SK ~50 m/s/yr + patrol (Soop 1994); merged insp/guardian';
    'Icy moon / ocean world orbiter',               100,          150,       'Europa frozen-orbit SK; RTG solves power not dose; shielding mass in trade';
    'SE-L1 space weather sentinel',                  15,           50,       '5-yr ops (3 m/s/yr); small in-situ node (CuSP/SWFO-L1); lifetime-bound pull-through';
    'Apophis 2029 hover / flyby',            15,           25,       'Prox-ops module (NOT rendezvous, cf. RAMSES 1530 m/s); needs Rogue-pub I_bit + RTG+';
};
n_prof = size(profile_defs, 1);

dV_duty_ceiling = rogue.F_baseline_N * rc_max.duty_cycle * spy / m_ref;

% RTG+ duty ceiling (same store, burst, thruster; only P_e changes).
rc_max_plus     = recharge(rtg_plus.P_design_W, mppt.eta, rtg.P_parasitic_W, ...
                           rogue.E_store_J, rogue.t_burst_max_s);
dV_duty_ceiling_plus = rogue.F_baseline_N * rc_max_plus.duty_cycle * spy / m_ref;

for i = 1:n_prof
    dV_req = profile_defs{i,2};
    m_sc   = profile_defs{i,3};

    dvL_1M  = delta_v_lifetime(rogue.I_bit_Ns, rogue.n_pulses_design,   m_sc, cfg.m_prop_sys_kg, rogue.Isp_s, g0);
    dvL_10M = delta_v_lifetime(rogue.I_bit_Ns, rogue.n_pulses_ambition, m_sc, cfg.m_prop_sys_kg, rogue.Isp_s, g0);
    dV_1M   = dvL_1M.dV_total_ms;
    dV_10M  = dvL_10M.dV_total_ms;

    dV_duty_i      = rogue.F_baseline_N * rc_max.duty_cycle * spy / m_sc;
    dV_duty_plus_i = rogue.F_baseline_N * rc_max_plus.duty_cycle * spy / m_sc;
    duty_ok        = dV_duty_i >= dV_req;
    duty_ok_plus   = dV_duty_plus_i >= dV_req;

    if dV_10M < dV_duty_i, bind10 = 'PULSE-LIFE'; else, bind10 = 'DUTY-CYCLE'; end

    mp(i).label              = profile_defs{i,1};
    mp(i).dV_req_ms          = dV_req;
    mp(i).m_sc_kg            = m_sc;
    mp(i).notes              = profile_defs{i,4};
    mp(i).I_req_Ns           = m_sc * dV_req;
    mp(i).dV_duty_max_ms     = dV_duty_i;
    mp(i).dV_duty_plus_ms    = dV_duty_plus_i;
    mp(i).dV_life_1M_ms      = dV_1M;
    mp(i).dV_life_10M_ms     = dV_10M;
    mp(i).feasible_duty      = duty_ok;
    mp(i).feasible_duty_plus = duty_ok_plus;
    mp(i).feasible_1M        = duty_ok      && (dV_1M  >= dV_req);
    mp(i).feasible_10M       = duty_ok      && (dV_10M >= dV_req);
    mp(i).feasible_10M_plus  = duty_ok_plus && (dV_10M >= dV_req);
    mp(i).binding_10M        = bind10;
end

%% ── F) N_PULSES BREAKEVEN PER MISSION PROFILE ───────────────────────────
% Minimum (I_bit, N_pulses) pair to close each profile, derived from exact
% Tsiolkovsky inversion: N_req = I_total_req / I_bit. Sweep extends to
% 10000 uN.s to bracket Warlock-scale comparators.

bkeven.I_bit_sweep_Ns  = logspace(log10(5e-6), log10(10000e-6), 120);
bkeven.N_req           = zeros(n_prof, numel(bkeven.I_bit_sweep_Ns));
bkeven.N_req_nominal   = zeros(1, n_prof);
for i = 1:n_prof
    dV_req      = profile_defs{i,2};
    m_sc        = profile_defs{i,3};
    m_prop_req  = m_sc * (1 - exp(-dV_req / (rogue.Isp_s * g0)));
    I_total_req = m_prop_req * rogue.Isp_s * g0;
    bkeven.N_req(i,:)        = I_total_req ./ bkeven.I_bit_sweep_Ns;
    bkeven.N_req_nominal(i)  = I_total_req / rogue.I_bit_Ns;
end

%% ── G) REQUIREMENTS ANALYSIS ────────────────────────────────────────────
% For each profile: N_pulses needed at the baseline I_bit, and the I_bit
% needed at the 10M-pulse ambition. E_pulse target derived from
% I_bit ~ E_pulse^alpha (alpha = 0.7).
%
% Exact Tsiolkovsky:
%   I_total_req = m_sc * (1 - exp(-dV / (Isp*g0))) * Isp * g0

for i = 1:n_prof
    dV_r = profile_defs{i,2};
    m_sc = profile_defs{i,3};
    m_prop_req  = m_sc * (1 - exp(-dV_r / (rogue.Isp_s * g0)));
    I_total_req = m_prop_req * rogue.Isp_s * g0;
    N_req_at_nom = I_total_req / rogue.I_bit_Ns;
    I_req_at_10M = I_total_req / rogue.n_pulses_ambition;

    tier = numel(cfg.req_tiers_Ns) + 1;
    for t = 1:numel(cfg.req_tiers_Ns)
        if I_total_req <= cfg.req_tiers_Ns(t), tier = t; break; end
    end

    if I_req_at_10M > rogue.I_bit_Ns
        E_pulse_req = rogue.E_per_pulse_J * (I_req_at_10M / rogue.I_bit_Ns)^(1/cfg.alpha_Ipulse);
    else
        E_pulse_req = rogue.E_per_pulse_J;
    end

    req(i).label                = profile_defs{i,1};
    req(i).dV_req_ms            = dV_r;
    req(i).m_sc_kg              = m_sc;
    req(i).I_total_req_Ns       = I_total_req;
    req(i).N_req_at_nom_M       = N_req_at_nom / 1e6;
    req(i).I_bit_req_at_10M_uNs = I_req_at_10M * 1e6;
    req(i).tier                 = tier;
    req(i).E_pulse_req_J        = E_pulse_req;
end

% Total impulse: confirmed-pulse model and propellant-implied figures.
I_total_current_Ns = rogue.I_bit_Ns  * rogue.n_pulses_ambition;
I_total_website_Ns = rogue.m_prop_kg * rogue.Isp_s * g0;

% Calendar lifetime: how long a finite pulse budget lasts at a given duty.
% Lifetime dV is set by total impulse, not duty cycle — lower duty spreads
% the same total firing time over more calendar time.
% (variable named cal_life to avoid shadowing MATLAB's calendar() builtin)
cal_life.N_pulses        = rogue.n_pulses_ambition;
cal_life.f_Hz            = rogue.f_Hz;
cal_life.t_fire_total_s  = cal_life.N_pulses / cal_life.f_Hz;
cal_life.duty_frac       = [rc_max.duty_cycle, 0.10, 0.03, 0.01, 0.003, 0.001];
cal_life.duty_pct        = 100 * cal_life.duty_frac;
cal_life.life_s          = cal_life.t_fire_total_s ./ cal_life.duty_frac;
cal_life.life_days       = cal_life.life_s / 86400;
cal_life.life_years      = cal_life.life_days / 365.25;
cal_life.model_duty_pct  = 100 * rc_max.duty_cycle;
cal_life.model_life_days = cal_life.life_days(1);   % alias: baseline-duty row

%% ── H) SPECIFIC MASS FRAMEWORK ──────────────────────────────────────────
% Four-part decomposition of system specific mass for the confirmed Rogue +
% RTG architecture, evaluated against a literature benchmark ladder and a
% propulsion-mass-fraction sweep. Sub-blocks:
%   H.1 Canonical alpha definitions      (source / PMAD / thruster / system / jet)
%   H.2 Stacking grid                    (preserved from prior version)
%   H.3 Per-profile threshold            (alpha_max(f_prop) curves)
%   H.4 System alpha breakeven           (max system alpha to close each profile)
%
% Conventions follow the NEP literature (Mason 2011; ASCEND 2025; Mesalam 2024):
%   alpha_source : kg per We at the power source output       [kg/We]
%   alpha_PMAD   : kg per We of charge-side regulation        [kg/We]
%   alpha_thr    : kg per N of thrust at the head             [kg/N]
%   alpha_system : (m_pwr + m_PMAD + m_thr) / P_e             [kg/We]
%   alpha_jet_inst : system mass per kW jet (instantaneous)   [kg/We jet]
%   alpha_jet_avg  : system mass per kW jet (duty-averaged)   [kg/We jet]
% with P_jet_inst = 0.5 * F * v_e and v_e = Isp * g0. The two jet alphas
% diverge at low duty cycle: alpha_jet_inst is the head-level figure of
% merit comparable to continuous-thrust EP; alpha_jet_avg is the mission-
% level mass per delivered jet kW.

% H.1) Canonical alphas at the confirmed operating point.
sm.f_prop_ref         = cfg.prop_mass_fraction_ref;
sm.alpha_rtg_kgWe     = rtg.specific_mass_kgWe;
sm.alpha_single_kgWe  = cfg.m_prop_sys_kg / rtg.P_design_W;

m_pwr_kg   = rtg.mass_kg;
m_PMAD_kg  = rogue.alloc.ppu_kg + rogue.alloc.store_kg + rogue.alloc.harness_kg;
m_head_kg  = rogue.alloc.head_kg;
m_sys_kg   = m_pwr_kg + m_PMAD_kg + m_head_kg;
P_e_W      = rtg.P_design_W;
v_e        = rogue.Isp_s * g0;
P_jet_inst = 0.5 * rogue.F_baseline_N * v_e;          % during pulse burst
P_jet_avg  = P_jet_inst * rc_max.duty_cycle;          % duty-averaged

sm.alpha.source_kgWe       = m_pwr_kg  / P_e_W;
sm.alpha.PMAD_kgWe         = m_PMAD_kg / P_e_W;
sm.alpha.thr_kgN           = m_head_kg / rogue.F_baseline_N;
sm.alpha.system_kgWe       = m_sys_kg  / P_e_W;
sm.alpha.jet_inst_kgWe     = m_sys_kg  / P_jet_inst;  % comparison with continuous EP (head terms)
sm.alpha.jet_avg_kgWe      = m_sys_kg  / P_jet_avg;   % mission-level mass per delivered jet kW
sm.alpha.P_jet_inst_W      = P_jet_inst;
sm.alpha.P_jet_avg_W       = P_jet_avg;
sm.alpha.duty              = rc_max.duty_cycle;
sm.alpha.m_pwr_kg          = m_pwr_kg;
sm.alpha.m_PMAD_kg         = m_PMAD_kg;
sm.alpha.m_head_kg         = m_head_kg;

% Position relative to literature benchmark ladder.
alpha_NEP_ref_kgWe = 0.005;   % mid-point of the SGL "achievable" NEP band (Turyshev 2026)
sm.bench = bench;
sm.bench.alpha_NEP_ref_kgWe    = alpha_NEP_ref_kgWe;
sm.bench.alpha_ratio_to_PA_RTG = bench.alpha_kgWe / rtg.specific_mass_kgWe;
sm.bench.alpha_ratio_to_NEP    = bench.alpha_kgWe / alpha_NEP_ref_kgWe;

% H.2) Specific-mass grid for all stacking combinations (unchanged numerics).
for nr = 1:cfg.n_stk_max
    for nt = 1:cfg.n_stk_max
        m_power = nt * rtg.mass_kg;
        m_thr   = nr * rogue.mass_kg;
        P_tot   = nt * rtg.P_design_W;
        sm.stack(nr,nt).n_rogue            = nr;
        sm.stack(nr,nt).n_rtg              = nt;
        sm.stack(nr,nt).mass_kg            = m_power + m_thr;
        sm.stack(nr,nt).power_We           = P_tot;
        sm.stack(nr,nt).alpha_power_kgWe   = m_power / P_tot;
        sm.stack(nr,nt).alpha_system_kgWe  = (m_power + m_thr) / P_tot;
    end
end

% H.3) Per-profile threshold across f_prop sweep.
% For each (profile, f_prop): minimum Rogue stack at confirmed I_bit x 10M,
% then maximum RTG alpha that fits the remaining mass allowance.
% Scalar fields (alpha_power_max_kgWe, etc.) retained at f_prop_ref for
% backwards compatibility with Plots.m Fig 9 and Summary.m section 6.

I_per_rogue_Ns = rogue.I_bit_Ns * rogue.n_pulses_ambition;
n_fp           = numel(cfg.prop_mass_fraction_sweep);
fp_idx_ref     = cfg.prop_mass_fraction_idx;

for i = 1:n_prof
    I_req       = req(i).I_total_req_Ns;
    nR_req      = max(1, ceil(I_req / I_per_rogue_Ns));
    P_req       = rtg.P_design_W;
    m_thr_req   = nR_req * rogue.mass_kg;

    % Sweep arrays across f_prop.
    alpha_max_grid    = nan(1, n_fp);
    target_pwr_grid   = nan(1, n_fp);
    target_mass_grid  = nan(1, n_fp);
    fit_now_grid      = false(1, n_fp);
    for k = 1:n_fp
        m_allow     = cfg.prop_mass_fraction_sweep(k) * req(i).m_sc_kg;
        m_pwr_allow = m_allow - m_thr_req;
        if m_pwr_allow > 0
            alpha_max_grid(k)   = m_pwr_allow / P_req;
            target_pwr_grid(k)  = rtg.mass_kg / alpha_max_grid(k);
            target_mass_grid(k) = alpha_max_grid(k) * rtg.P_design_W;
            fit_now_grid(k)     = rtg.specific_mass_kgWe <= alpha_max_grid(k);
        end
    end

    sm.threshold(i).label              = req(i).label;
    sm.threshold(i).I_req_Ns           = I_req;
    sm.threshold(i).m_sc_kg            = req(i).m_sc_kg;
    sm.threshold(i).n_rogue_req        = nR_req;
    sm.threshold(i).P_req_We           = P_req;
    sm.threshold(i).m_thr_req_kg       = m_thr_req;

    % Sweep results.
    sm.threshold(i).f_prop_sweep                = cfg.prop_mass_fraction_sweep;
    sm.threshold(i).alpha_power_max_grid_kgWe   = alpha_max_grid;
    sm.threshold(i).target_rtg_power_grid_We    = target_pwr_grid;
    sm.threshold(i).target_rtg_mass_grid_kg     = target_mass_grid;
    sm.threshold(i).fit_now_grid                = fit_now_grid;

    % Backwards-compatible scalar at f_prop_ref.
    sm.threshold(i).m_allow_kg                  = cfg.prop_mass_fraction_ref * req(i).m_sc_kg;
    sm.threshold(i).alpha_power_max_kgWe        = alpha_max_grid(fp_idx_ref);
    sm.threshold(i).target_rtg_power_We_at_mass = target_pwr_grid(fp_idx_ref);
    sm.threshold(i).target_rtg_mass_kg_at_design= target_mass_grid(fp_idx_ref);
    if isnan(alpha_max_grid(fp_idx_ref))
        sm.threshold(i).rtg_mass_reduction_pct  = NaN;
        sm.threshold(i).fit_now                 = false;
    else
        sm.threshold(i).rtg_mass_reduction_pct  = 100 * (1 - target_mass_grid(fp_idx_ref) / rtg.mass_kg);
        sm.threshold(i).fit_now                 = fit_now_grid(fp_idx_ref);
    end
end

% H.4) System alpha breakeven per profile.
% Maximum permitted *system* specific mass (kg/We at thruster electrical
% input) such that the closing Rogue stack plus its power source equals the
% mass allowance. Treats the head as fixed and the source as the variable.
% alpha_sys_max = m_allow / (nR * P_e_per_rogue) where P_e_per_rogue is the
% confirmed RTG design power (one RTG per Rogue assumed for breakeven).

for i = 1:n_prof
    nR     = sm.threshold(i).n_rogue_req;
    P_pool = nR * rtg.P_design_W;

    alpha_sys_max_grid = nan(1, n_fp);
    margin_grid_kg     = nan(1, n_fp);
    for k = 1:n_fp
        m_allow = cfg.prop_mass_fraction_sweep(k) * req(i).m_sc_kg;
        if m_allow > 0
            alpha_sys_max_grid(k) = m_allow / P_pool;
            margin_grid_kg(k)     = m_allow - (nR * rogue.mass_kg + nR * rtg.mass_kg);
        end
    end

    sm.breakeven(i).label                  = req(i).label;
    sm.breakeven(i).m_sc_kg                = req(i).m_sc_kg;
    sm.breakeven(i).nR                     = nR;
    sm.breakeven(i).P_pool_We              = P_pool;
    sm.breakeven(i).f_prop_sweep           = cfg.prop_mass_fraction_sweep;
    sm.breakeven(i).alpha_sys_max_grid_kgWe = alpha_sys_max_grid;
    sm.breakeven(i).margin_grid_kg         = margin_grid_kg;
    sm.breakeven(i).alpha_sys_now_kgWe     = (nR*rogue.mass_kg + nR*rtg.mass_kg) / P_pool;
    sm.breakeven(i).fits_at_ref            = sm.breakeven(i).alpha_sys_now_kgWe <= alpha_sys_max_grid(fp_idx_ref);
end

%% ── I) dV vs SPACECRAFT MASS ────────────────────────────────────────────
% Dual-constraint dV at the baseline operating point with I_bit envelope.
% delta_v() uses the small-dV propellant-mass approximation.
% delta_v_lifetime() uses full Tsiolkovsky for the total-life budget.
for i = 1:numel(cfg.m_sc_kg)
    m     = cfg.m_sc_kg(i);
    dv    = delta_v(rogue.F_baseline_N,     rogue.Isp_s, pt.duty_cycle, cfg.mission_days, m, cfg.m_prop_sys_kg, g0);
    dv_lo = delta_v(rogue.F_baseline_min_N, rogue.Isp_s, pt.duty_cycle, cfg.mission_days, m, cfg.m_prop_sys_kg, g0);
    dv_hi = delta_v(rogue.F_baseline_max_N, rogue.Isp_s, pt.duty_cycle, cfg.mission_days, m, cfg.m_prop_sys_kg, g0);
    dvL_1  = delta_v_lifetime(rogue.I_bit_Ns, rogue.n_pulses_design,   m, cfg.m_prop_sys_kg, rogue.Isp_s, g0);
    dvL_10 = delta_v_lifetime(rogue.I_bit_Ns, rogue.n_pulses_ambition, m, cfg.m_prop_sys_kg, rogue.Isp_s, g0);
    dV_pyr_10 = dvL_10.dV_total_ms / cfg.mission_years;
    if dV_pyr_10 < dv.dV_ms, b10 = 'PULSE'; else, b10 = 'DUTY'; end

    dv_sc(i) = struct( ...
        'm_sc_kg',              m, ...
        'payload_kg',           max(0, m - cfg.m_prop_sys_kg), ...
        'dV_duty_ms',           dv.dV_ms, ...
        'dV_duty_lo_ms',        dv_lo.dV_ms, ...
        'dV_duty_hi_ms',        dv_hi.dV_ms, ...
        'dV_life_1M_total_ms',  dvL_1.dV_total_ms, ...
        'dV_life_10M_total_ms', dvL_10.dV_total_ms, ...
        'dV_actual_10M_ms',     nan_safe_min(dv.dV_ms, dV_pyr_10), ...
        'binding_10M',          b10, ...
        'prop_frac_pct',        cfg.m_prop_sys_kg / m * 100);
end

%% ── J) STACKING ANALYSIS (n_rogue x n_rtg grid) ─────────────────────────
% Evaluates all (n_rogue, n_rtg) combinations from 1 to n_stk_max each.
%
% Orthogonal levers:
%   n_Rogue -> thrust, burst duration, pulse budget, lifetime dV
%   n_RTG   -> duty cycle and recharge time only
%
% Derivation (n_r = n_Rogue, n_t = n_RTG, P_net = single-RTG net power):
%   t_burst = n_r * E_store / (E_pulse * f)     [proportional to n_r]
%   t_rchg  = n_r * E_store / (n_t * P_net)     [proportional to n_r/n_t]
%   duty    = t_burst / (t_burst + t_rchg)
%           = 1 / (1 + E_pulse*f / (n_t*P_net)) [n_r cancels]
%
% Simultaneous firing assumed (worst case for pulse consumption rate);
% sequential firing yields identical lifetime dV.

n_stk = cfg.n_stk_max;

for nr = 1:n_stk
    for nt = 1:n_stk
        s = stack_perf(nr, nt, rogue, rtg, mppt);
        s.I_total_Ns = rogue.I_bit_Ns * s.n_pulses;
        for mi = 1:numel(cfg.m_sc_stack_kg)
            m_sc = cfg.m_sc_stack_kg(mi);
            if m_sc > s.m_sys_kg
                dv_d = delta_v(s.F_N, rogue.Isp_s, s.duty, cfg.mission_days, m_sc, s.m_sys_kg, g0);
                dvL  = delta_v_lifetime(rogue.I_bit_Ns, s.n_pulses, m_sc, s.m_sys_kg, rogue.Isp_s, g0);
                s.dV_duty_ms(mi) = dv_d.dV_ms;
                s.dV_life_ms(mi) = dvL.dV_total_ms;
            else
                s.dV_duty_ms(mi) = NaN;
                s.dV_life_ms(mi) = NaN;
            end
        end
        stk(nr, nt) = s;
    end
end
stk_m_sc = cfg.m_sc_stack_kg;

% Display grids indexed as (n_RTG, n_Rogue): x-axis n_Rogue, y-axis n_RTG.
% Band patterns confirm orthogonality: duty horizontal; dV/thrust vertical;
% mass/recharge diagonal.
for nt = 1:n_stk
    for nr = 1:n_stk
        s = stk(nr, nt);
        stk_grid.duty(nt, nr)         = s.duty * 100;
        stk_grid.mass(nt, nr)         = s.m_sys_kg;
        stk_grid.dV(nt, nr)           = s.dV_life_ms(1);
        stk_grid.burst(nt, nr)        = s.t_burst_s;
        stk_grid.thrust(nt, nr)       = s.F_N * 1e3;
        stk_grid.rchg_min(nt, nr)     = s.t_rchg_min;
        stk_grid.alpha_power(nt, nr)  = rtg.specific_mass_kgWe;
        stk_grid.alpha_system(nt, nr) = s.m_sys_kg / (nt * rtg.P_design_W);
    end
end

% Mission unlock: which (n_r, n_t) configurations close each profile.
for i = 1:n_prof
    for mi = 1:numel(cfg.m_sc_stack_kg)
        dV_req = profile_defs{i,2};
        m_sc   = cfg.m_sc_stack_kg(mi);
        feas   = false(n_stk, n_stk);
        for nr = 1:n_stk
            for nt = 1:n_stk
                s = stk(nr, nt);
                if m_sc <= s.m_sys_kg, continue; end
                dv_d = delta_v(s.F_N, rogue.Isp_s, s.duty, cfg.mission_days, m_sc, s.m_sys_kg, g0);
                dvL  = delta_v_lifetime(rogue.I_bit_Ns, s.n_pulses, m_sc, s.m_sys_kg, rogue.Isp_s, g0);
                feas(nr,nt) = ~isnan(dv_d.dV_ms)     && (dv_d.dV_ms     >= dV_req) && ...
                              ~isnan(dvL.dV_total_ms) && (dvL.dV_total_ms >= dV_req);
            end
        end
        stk_unlock(i,mi).label         = profile_defs{i,1};
        stk_unlock(i,mi).dV_req_ms     = dV_req;
        stk_unlock(i,mi).m_sc_kg       = m_sc;
        stk_unlock(i,mi).feasible_grid = feas;
    end
end

% Isp sensitivity: dV at the reference mass, single Rogue, 10M pulses.
for ii = 1:numel(cfg.Isp_sweep_s)
    Isp_i  = cfg.Isp_sweep_s(ii);
    dvL_i  = delta_v_lifetime(rogue.I_bit_Ns, rogue.n_pulses_ambition, m_ref, cfg.m_prop_sys_kg, Isp_i, g0);
    I_impl = rogue.m_prop_kg * Isp_i * g0;
    sw_Isp(ii) = struct( ...
        'Isp_s',              Isp_i, ...
        'dV_ref_ms',          dvL_i.dV_total_ms, ...
        'I_total_implied_Ns', I_impl, ...
        'N_implied_M',        I_impl / rogue.I_bit_Ns / 1e6);
end

%% ── K) FREQUENCY SWEEP (F = I_bit x f invariance) ───────────────────────
% Annual dV is invariant in frequency: lower f gives longer burst but
% proportionally lower thrust. Lower f buys lifetime extension by reducing
% annual pulse consumption.
for fi = 1:numel(cfg.f_sweep_Hz)
    f     = cfg.f_sweep_Hz(fi);
    t_max = rogue.E_store_J / (rogue.E_per_pulse_J * f);
    rc    = recharge(rtg.P_design_W, mppt.eta, rtg.P_parasitic_W, rogue.E_store_J, t_max);
    F_f   = rogue.I_bit_Ns     * f;
    F_lo  = rogue.I_bit_min_Ns * f;
    F_hi  = rogue.I_bit_max_Ns * f;
    dvf    = delta_v(F_f,  rogue.Isp_s, rc.duty_cycle, cfg.mission_days, m_ref, cfg.m_prop_sys_kg, g0);
    dvf_lo = delta_v(F_lo, rogue.Isp_s, rc.duty_cycle, cfg.mission_days, m_ref, cfg.m_prop_sys_kg, g0);
    dvf_hi = delta_v(F_hi, rogue.Isp_s, rc.duty_cycle, cfg.mission_days, m_ref, cfg.m_prop_sys_kg, g0);
    ap_f   = f * t_max * spy / (t_max + rc.t_recharge_s);
    sw_freq(fi) = struct( ...
        'f_Hz',          f, ...
        't_max_s',       t_max, ...
        't_rchg_min',    rc.t_recharge_min, ...
        'duty',          rc.duty_cycle, ...
        'F_N',           F_f, ...
        'dV_ms',         dvf.dV_ms, ...
        'dV_lo_ms',      dvf_lo.dV_ms, ...
        'dV_hi_ms',      dvf_hi.dV_ms, ...
        'annual_pulses', ap_f, ...
        'life_10M_days', rogue.n_pulses_ambition / ap_f * 365.25);
end

%% ── L) E_PULSE -> I_BIT SCALING (alpha sweep) ───────────────────────────
% I_bit = I_bit_ref * (E_pulse/E_pulse_ref)^alpha. Reducing E_pulse extends
% burst but drops I_bit faster than pulse count grows. Net effect on lifetime
% dV is always negative.
sw_epulse.E_pulse_J    = cfg.E_pulse_sweep_J;
sw_epulse.alpha        = cfg.alpha_sweep;
sw_epulse.I_bit_grid   = zeros(numel(cfg.alpha_sweep), numel(cfg.E_pulse_sweep_J));
sw_epulse.F_grid       = zeros(numel(cfg.alpha_sweep), numel(cfg.E_pulse_sweep_J));
sw_epulse.dV_life_grid = zeros(numel(cfg.alpha_sweep), numel(cfg.E_pulse_sweep_J));
for ai = 1:numel(cfg.alpha_sweep)
    a = cfg.alpha_sweep(ai);
    for ei = 1:numel(cfg.E_pulse_sweep_J)
        Ep  = cfg.E_pulse_sweep_J(ei);
        I_b = rogue.I_bit_Ns * (Ep / cfg.E_pulse_ref_J)^a;
        dvL = delta_v_lifetime(I_b, rogue.n_pulses_ambition, m_ref, cfg.m_prop_sys_kg, rogue.Isp_s, g0);
        sw_epulse.I_bit_grid(ai,ei)   = I_b;
        sw_epulse.F_grid(ai,ei)       = I_b * rogue.f_Hz;
        sw_epulse.dV_life_grid(ai,ei) = dvL.dV_total_ms;
    end
end

%% ── M) STORE SIZE: BURST AND RECHARGE SCALING ──────────────────────────
% At fixed pulse parameters (E_pulse, f), the burst-recharge cycle has duty
%   duty = 1 / (1 + E_pulse * f / P_net)
% which is independent of store size. Store size therefore controls the
% absolute burst and recharge durations, not the duty cycle or the annual
% deliverable dV. The sweep records both quantities and the cycle period
% across stores from 100 J to the baseline (10 kJ accessible).
sw_store.m_sc_kg   = m_ref;
sw_store.E_store_J = logspace(2, log10(rogue.E_store_full_J), 60);
sw_store.t_burst_s   = sw_store.E_store_J / (rogue.E_per_pulse_J * rogue.f_Hz);
sw_store.t_rchg_s    = sw_store.E_store_J / (rtg.P_design_W * mppt.eta - rtg.P_parasitic_W);
sw_store.t_cycle_s   = sw_store.t_burst_s + sw_store.t_rchg_s;
sw_store.duty        = sw_store.t_burst_s ./ sw_store.t_cycle_s;
sw_store.dV_per_cycle_ms = rogue.F_baseline_N .* sw_store.t_burst_s / m_ref;
sw_store.dV_annual_ms    = rogue.F_baseline_N .* sw_store.duty * spy / m_ref;
sw_store.dV_life_ms      = dV_cap_10M_ms;

%% ── N) RTG POWER SENSITIVITY ────────────────────────────────────────────
% Recharge time grid over (P_RTG, E_store).
[Np, Ne] = deal(numel(cfg.P_RTG_sweep_W), numel(cfg.E_store_sweep_J));
sw_pwr.t_recharge_grid = zeros(Ne, Np);
for i = 1:Ne
    for j = 1:Np
        rc = recharge(cfg.P_RTG_sweep_W(j), mppt.eta, rtg.P_parasitic_W, ...
                      cfg.E_store_sweep_J(i), cfg.t_burst_s);
        sw_pwr.t_recharge_grid(i,j) = rc.t_recharge_s;
    end
end
sw_pwr.P_RTG_W   = cfg.P_RTG_sweep_W;
sw_pwr.E_store_J = cfg.E_store_sweep_J;

% Burst duration sensitivity at baseline power and frequency.
for b = 1:numel(cfg.t_burst_sweep_s)
    tb  = cfg.t_burst_sweep_s(b);
    rc  = recharge(rtg.P_design_W, mppt.eta, rtg.P_parasitic_W, rogue.E_store_J, tb);
    dvb = delta_v(rogue.F_baseline_N, rogue.Isp_s, rc.duty_cycle, cfg.mission_days, ...
                  m_ref, cfg.m_prop_sys_kg, g0);
    sw_burst(b) = struct('t_s', tb, 'duty', rc.duty_cycle, ...
        't_cycle_s', tb + rc.t_recharge_s, 'dV_ms', dvb.dV_ms);
end

% Discrete RTG power cases (lab range and design target).
for p = 1:numel(cfg.P_RTG_cases_We)
    P_p = cfg.P_RTG_cases_We(p);
    rc  = recharge(P_p, mppt.eta, rtg.P_parasitic_W, rogue.E_store_J, cfg.t_burst_s);
    dvp = delta_v(rogue.F_baseline_N, rogue.Isp_s, rc.duty_cycle, cfg.mission_days, ...
                  m_ref, cfg.m_prop_sys_kg, g0);
    sw_power(p) = struct('P_We', P_p, 'P_net_W', rc.P_net_W, ...
        't_min', rc.t_recharge_min, 'duty', rc.duty_cycle, 'dV_ms', dvp.dV_ms);
end

%% ── O) LIFETIME GRIDS ───────────────────────────────────────────────────
% Grid (a): frequency x energy store, fixed E_pulse = baseline.
for fi = 1:numel(cfg.f_sweep_Hz)
    for ei = 1:numel(cfg.E_store_sweep_J)
        f  = cfg.f_sweep_Hz(fi);   E = cfg.E_store_sweep_J(ei);
        tm = E / (rogue.E_per_pulse_J * f);
        rc = recharge(rtg.P_design_W, mppt.eta, rtg.P_parasitic_W, E, tm);
        ap = f * tm * spy / (tm + rc.t_recharge_s);
        lfe.life_1M(fi,ei)  = rogue.n_pulses_design   / ap;
        lfe.life_10M(fi,ei) = rogue.n_pulses_ambition / ap;
        lfe.duty(fi,ei)     = rc.duty_cycle;
    end
end
lfe.f_Hz      = cfg.f_sweep_Hz;
lfe.E_store_J = cfg.E_store_sweep_J;

% Grid (b): frequency x pulse energy, fixed E_store = baseline.
for fi = 1:numel(cfg.f_sweep_Hz)
    for ei_O = 1:numel(cfg.E_pulse_sweep_J)
        f  = cfg.f_sweep_Hz(fi);   Ep = cfg.E_pulse_sweep_J(ei_O);
        tm = rogue.E_store_J / (Ep * f);
        rc = recharge(rtg.P_design_W, mppt.eta, rtg.P_parasitic_W, rogue.E_store_J, tm);
        ap = f * tm * spy / (tm + rc.t_recharge_s);
        I_b_eff = rogue.I_bit_Ns * (Ep / cfg.E_pulse_ref_J)^cfg.alpha_Ipulse;
        dvL = delta_v_lifetime(I_b_eff, rogue.n_pulses_ambition, m_ref, cfg.m_prop_sys_kg, rogue.Isp_s, g0);
        lfep.life_1M(fi,ei_O)     = rogue.n_pulses_design   / ap;
        lfep.life_10M(fi,ei_O)    = rogue.n_pulses_ambition / ap;
        lfep.dV_life_10M(fi,ei_O) = dvL.dV_total_ms;
        lfep.duty(fi,ei_O)        = rc.duty_cycle;
    end
end
lfep.f_Hz      = cfg.f_sweep_Hz;
lfep.E_pulse_J = cfg.E_pulse_sweep_J;

% Annual pulse count below which pulse-life always binds.
sw_cross.N_max_per_yr = rogue.f_Hz * rc_max.duty_cycle * spy;

%% ── P) RTG FIN THERMAL EQUILIBRIUM ──────────────────────────────────────
% Stefan-Boltzmann balance on the radiating fin surface (deep space, 3 K
% background). Lab-min case is the conservative (hottest) fin estimate;
% design case is nominal. Housing remains isothermal at ~25 degC regardless.
Q_waste_lab     = heater.P_W - rtg.P_lab_min_W;
Q_waste_design  = heater.P_W - rtg.P_design_W;

T_eq_K_design   = (Q_waste_design / (rtg.emissivity * sigma * rtg.A_radiate_m2))^0.25;
T_eq_K_lab      = (Q_waste_lab    / (rtg.emissivity * sigma * rtg.A_radiate_m2))^0.25;

A_sw = linspace(0.01, 1.0, 200);
th_rtg.Q_waste_W      = Q_waste_design;
th_rtg.Q_waste_lab_W  = Q_waste_lab;
th_rtg.T_eq_C         = T_eq_K_design - 273.15;
th_rtg.T_eq_lab_C     = T_eq_K_lab    - 273.15;
th_rtg.A_sweep_m2     = A_sw;
th_rtg.T_sweep_C      = (Q_waste_design ./ (rtg.emissivity * sigma * A_sw)).^0.25 - 273.15;

% Limit checks against the fin-adhesive lower bound (ICD Table 2-1).
th_rtg.adhesive_limit_C      = rtg.T_adhesive_C(1);
th_rtg.adhesive_margin_C     = th_rtg.T_eq_C     - th_rtg.adhesive_limit_C;
th_rtg.adhesive_margin_lab_C = th_rtg.T_eq_lab_C - th_rtg.adhesive_limit_C;
th_rtg.adhesive_ok           = th_rtg.adhesive_margin_C     >= 0;
th_rtg.adhesive_ok_lab       = th_rtg.adhesive_margin_lab_C >= 0;

%% ── Q) ROGUE THERMAL ANALYSIS ───────────────────────────────────────────
% Near-adiabatic burst: each component absorbs its own dissipated heat.
% First-order estimates only — for handoff to a coupled FEM model.
T0_K = rogue.th.T_ambient_C + 273.15;

% Radiated energy during burst (small — confirms near-adiabatic assumption).
Q_rad = rogue.th.emissivity * sigma * rogue.th.A_walls_m2 * ...
        ((T0_K + rogue.th.dT_hotwall_avg_C)^4 - T0_K^4) * cfg.t_burst_s;

% Per-node thermal capacitance: C = P_dissipated * t_burst / dT_peak.
C_PPS   = rogue.th.P_PPS_W   * cfg.t_burst_s / rogue.th.dT_PPS_pk_C;
C_motor = rogue.th.P_motor_W * cfg.t_burst_s / rogue.th.dT_motor_pk_C;
C_HVG   = rogue.th.P_HVG_W   * cfg.t_burst_s / rogue.th.dT_HVG_pk_C;
C_elec  = C_PPS + C_motor + C_HVG;

% Apparent transient R_th at t = 10 s (component-to-casing).
R_PPS   = (rogue.th.dT_PPS_C   - rogue.th.dT_hotwall_C) / rogue.th.P_PPS_W;
R_motor = (rogue.th.dT_motor_C - rogue.th.dT_hotwall_C) / rogue.th.P_motor_W;
R_HVG   = (rogue.th.dT_HVG_C   - rogue.th.dT_hotwall_C) / rogue.th.P_HVG_W;

% Casing thermal capacitance from post-burn energy balance (t = 10 s -> 17.25 s).
Q_elec_released = C_PPS   * (rogue.th.dT_PPS_C       - rogue.th.dT_PPS_at_hwpeak_C)   + ...
                  C_motor * (rogue.th.dT_motor_pk_C  - rogue.th.dT_motor_at_hwpeak_C) + ...
                  C_HVG   * (rogue.th.dT_HVG_pk_C    - rogue.th.dT_HVG_at_hwpeak_C);
t_postburn  = rogue.th.t_hwpeak_s - cfg.t_burst_s;
Q_rad_pb    = rogue.th.emissivity * sigma * rogue.th.A_walls_m2 * ...
              ((T0_K + rogue.th.dT_hotwall_C)^4 - T0_K^4) * t_postburn;
dT_cas_rise = rogue.th.dT_hwpeak_C - rogue.th.dT_hotwall_C;
C_casing    = (Q_elec_released - Q_rad_pb) / dT_cas_rise;

% Casing capacitance bounds (pure Al upper; mixed electronics lower).
C_cas_upper = rogue.mass_kg * rogue.th.c_p_Al_JkgK;
C_cas_lower = rogue.mass_kg * rogue.th.c_p_elec_JkgK;

% Summary scalars.
dT_int_avg = mean([rogue.th.dT_PPS_C, rogue.th.dT_motor_C, rogue.th.dT_HVG_C]);
dT_ratio   = dT_int_avg / rogue.th.dT_hotwall_C;
tau_cool   = rogue.th.tau_motor_s;
t_to_1degC = -tau_cool * log(1.0 / rogue.th.dT_motor_pk_C);

th_rogue = struct( ...
    'Q_rad_J',           Q_rad, ...
    'Q_stored_J',        rogue.th.E_internal_J - Q_rad, ...
    'C_PPS_JK',          C_PPS, ...
    'C_motor_JK',        C_motor, ...
    'C_HVG_JK',          C_HVG, ...
    'C_elec_JK',         C_elec, ...
    'C_casing_JK',       C_casing, ...
    'C_casing_upper_JK', C_cas_upper, ...
    'C_casing_lower_JK', C_cas_lower, ...
    'R_PPS_KW',          R_PPS, ...
    'R_motor_KW',        R_motor, ...
    'R_HVG_KW',          R_HVG, ...
    'dT_int_avg_C',      dT_int_avg, ...
    'dT_ratio',          dT_ratio, ...
    'tau_s',             tau_cool, ...
    't_to_1degC_s',      t_to_1degC);

% Recharge vs cooldown margin at each RTG power case.
for pc = 1:numel(cfg.P_RTG_cases_We)
    rc_tc = recharge(cfg.P_RTG_cases_We(pc), mppt.eta, rtg.P_parasitic_W, ...
                     rogue.E_store_J, cfg.t_burst_s);
    th_rogue.t_recharge_s(pc) = rc_tc.t_recharge_s;
    th_rogue.margin_s(pc)     = rc_tc.t_recharge_s - t_to_1degC;
end

%% ── R) TORQUE ANALYSIS (gated on mounting config) ───────────────────────
% Set cfg.rogue_origin_in_RTG_m to unlock. Inertia tensor uses parallel-axis
% theorem on all three diagonal components from each body's principal axes.
torque.computed = false;
torque.note     = 'Set cfg.rogue_origin_in_RTG_m once mounting is defined.';
if ~any(isnan(cfg.rogue_origin_in_RTG_m))
    rogue_CoM_RTG = cfg.rogue_origin_in_RTG_m + rogue.CoM_m;
    M_tot         = rtg.mass_kg + rogue.mass_kg;
    sys_CoM       = (rtg.mass_kg*rtg.CoM_m + rogue.mass_kg*rogue_CoM_RTG) / M_tot;
    r             = rogue_CoM_RTG - sys_CoM;
    F_hat         = rogue.thrust_vec / norm(rogue.thrust_vec);
    r_perp        = r - dot(r,F_hat)*F_hat;
    tau_vec       = cross(r, rogue.F_baseline_N*F_hat);

    % Parallel-axis system inertia about the system CoM, all three axes.
    d_rtg = rtg.CoM_m  - sys_CoM;
    d_rog = rogue_CoM_RTG - sys_CoM;
    I_rtg_diag = [rtg.Ixx_kgm2; rtg.Iyy_kgm2; rtg.Izz_kgm2];
    I_rog_diag = rogue.inertia_kgm2(:);
    I_sys_diag = I_rtg_diag + rtg.mass_kg   * (sum(d_rtg.^2) - d_rtg(:).^2) + ...
                 I_rog_diag + rogue.mass_kg * (sum(d_rog.^2) - d_rog(:).^2);

    % Project torque onto principal axes to get effective angular acceleration.
    alpha_vec    = tau_vec(:) ./ I_sys_diag;
    alpha_mag    = norm(alpha_vec);

    torque = struct( ...
        'computed',        true, ...
        'sys_CoM_m',       sys_CoM, ...
        'tau_vec_Nm',      tau_vec, ...
        'tau_mag_Nm',      norm(tau_vec), ...
        'arm_mm',          norm(r_perp)*1e3, ...
        'I_sys_diag_kgm2', I_sys_diag, ...
        'alpha_vec_rads2', alpha_vec, ...
        'alpha_mag_rads2', alpha_mag, ...
        'drift_deg',       0.5*rad2deg(alpha_mag)*cfg.t_burst_s^2, ...
        'ang_impulse_Nms', rogue.I_bit_Ns * norm(r_perp));
end

%% ── S) MASS BUDGET ──────────────────────────────────────────────────────
mass.rtg_kg          = rtg.mass_kg;
mass.rogue_kg        = rogue.mass_kg;
mass.rogue_head_kg   = rogue.alloc.head_kg;
mass.rogue_PMAD_kg   = rogue.alloc.ppu_kg + rogue.alloc.store_kg + rogue.alloc.harness_kg;
mass.coupling_kg     = NaN;   % pending external interface
mass.mppt_kg         = NaN;   % pending external regulator
mass.total_kg        = cfg.m_prop_sys_kg;
mass.sp_power_min_Wkg = rtg.P_lab_min_W / rtg.mass_kg;
mass.sp_power_max_Wkg = rtg.P_design_W  / rtg.mass_kg;

%% ── T) PACKAGE INTO NEP STRUCT ──────────────────────────────────────────
NEP.profile_defs       = profile_defs;
NEP.req                = req;
NEP.I_total_current_Ns = I_total_current_Ns;
NEP.I_total_website_Ns = I_total_website_Ns;
NEP.stk                = stk;
NEP.stk_grid           = stk_grid;
NEP.stk_unlock         = stk_unlock;
NEP.stk_m_sc           = stk_m_sc;
NEP.sw_Isp             = sw_Isp;
NEP.params             = struct('rtg',rtg,'rogue',rogue,'mppt',mppt,'heater',heater,'cfg',cfg,'rtg_plus',rtg_plus,'rsg',rsg);
NEP.const              = struct('g0',g0,'sigma',sigma);
NEP.teg                = teg;
NEP.pt                 = pt;
NEP.rc_max             = rc_max;
NEP.rc_max_plus        = rc_max_plus;
NEP.cap                = cap;
NEP.dV_cap_10M_ms      = dV_cap_10M_ms;
NEP.dV_duty_ceiling      = dV_duty_ceiling;
NEP.dV_duty_ceiling_plus = dV_duty_ceiling_plus;
NEP.calendar           = cal_life;
NEP.sm                 = sm;
NEP.mp                 = mp;
NEP.bkeven             = bkeven;
NEP.dv_sc              = dv_sc;
NEP.sw_freq            = sw_freq;
NEP.sw_epulse          = sw_epulse;
NEP.sw_store           = sw_store;
NEP.sw_burst           = sw_burst;
NEP.sw_power           = sw_power;
NEP.sw_pwr             = sw_pwr;
NEP.lfe                = lfe;
NEP.lfep               = lfep;
NEP.sw_cross           = sw_cross;
NEP.th_rtg             = th_rtg;
NEP.th_rogue           = th_rogue;
NEP.torque             = torque;
NEP.mass               = mass;

fprintf('MicroNEP_Model complete.\n');
fprintf('  Net power     : %.2f W   | Recharge %.1f min | Duty %.2f%%\n', ...
    rc_max.P_net_W, rc_max.t_recharge_min, rc_max.duty_cycle*100);
fprintf('  Thrust        : %.2f mN  at %.0f Hz  (I_bit %.0f uN.s)\n', ...
    rogue.F_baseline_N*1e3, rogue.f_Hz, rogue.I_bit_Ns*1e6);
fprintf('  Lifetime dV   : %.2f m/s at %.0f kg, %.0fM pulses\n', ...
    dV_cap_10M_ms, m_ref, rogue.n_pulses_ambition/1e6);
fprintf('  RTG fin       : %.1f degC design  | %.1f degC lab-min\n', ...
    th_rtg.T_eq_C, th_rtg.T_eq_lab_C);
if ~th_rtg.adhesive_ok
    fprintf('  ** FLAG       : design-case fin %.1f degC is %.1f degC BELOW the %.0f degC adhesive limit\n', ...
        th_rtg.T_eq_C, -th_rtg.adhesive_margin_C, th_rtg.adhesive_limit_C);
end
fprintf('  Total impulse : %.0f Ns pulse-model  | %.0f Ns propellant-implied\n', ...
    I_total_current_Ns, I_total_website_Ns);
fprintf('  Specific mass : alpha_sys %.2f kg/We  | alpha_jet inst %.1f / avg %.0f kg/We jet  | bench band %.3f - %.2f kg/We\n', ...
    sm.alpha.system_kgWe, sm.alpha.jet_inst_kgWe, sm.alpha.jet_avg_kgWe, ...
    min(bench.alpha_kgWe), max(bench.alpha_kgWe));

%% ── LOCAL FUNCTIONS ─────────────────────────────────────────────────────

function s = stack_perf(n_r, n_t, rogue, rtg, mppt)
% Performance metrics for n_r Rogues + n_t RTGs.
% Duty depends only on n_t (n_r cancels). dV depends only on n_r.
    P_net_total = n_t * (rtg.P_design_W * mppt.eta - rtg.P_parasitic_W);
    E_store_tot = n_r * rogue.E_store_J;
    t_burst     = E_store_tot / (rogue.E_per_pulse_J * rogue.f_Hz);
    t_rchg      = E_store_tot / P_net_total;
    s.n_rogue    = n_r;
    s.n_rtg      = n_t;
    s.P_net_W    = P_net_total;
    s.E_store_J  = E_store_tot;
    s.t_burst_s  = t_burst;
    s.t_rchg_s   = t_rchg;
    s.t_rchg_min = t_rchg / 60;
    s.duty       = t_burst / (t_burst + t_rchg);
    s.F_N        = n_r * rogue.I_bit_Ns * rogue.f_Hz;
    s.m_sys_kg   = n_t * rtg.mass_kg + n_r * rogue.mass_kg;
    s.n_pulses   = n_r * rogue.n_pulses_ambition;
    s.dV_duty_ms = [];
    s.dV_life_ms = [];
end

function rc = recharge(P_RTG, eta, P_par, E_store, t_burst)
% Recharge time, duty cycle, and net power.
    P_net = P_RTG * eta - P_par;
    if P_net <= 0
        rc = struct('P_net_W',P_net,'t_recharge_s',Inf,'t_recharge_min',Inf,'duty_cycle',0);
        return
    end
    t_r = E_store / P_net;
    rc  = struct('P_net_W',P_net,'t_recharge_s',t_r,'t_recharge_min',t_r/60, ...
                 'duty_cycle',t_burst/(t_burst+t_r));
end

function dv = delta_v(F, Isp, duty, days, m_sc, m_sys, g0)
% Duty-cycle-limited annual dV. Exact Tsiolkovsky for the delivered impulse:
% m_prop = F*t_burn/(Isp*g0) holds identically for constant Isp, so no
% small-dV approximation is involved.
    if m_sc <= m_sys
        dv = struct('t_burn_s',0,'dV_ms',NaN,'feasible',false); return
    end
    t_burn = days * 86400 * duty;
    m_prop = F * t_burn / (Isp * g0);
    if m_prop >= m_sc - m_sys
        dv = struct('t_burn_s',t_burn,'dV_ms',NaN,'feasible',false); return
    end
    dv = struct('t_burn_s',t_burn,'feasible',true, ...
                'dV_ms', Isp*g0*log(m_sc/(m_sc-m_prop)));
end

function dvL = delta_v_lifetime(I_bit, n_pulses, m_sc, m_sys, Isp, g0)
% Total lifetime dV from full pulse budget (exact Tsiolkovsky).
% Invariant in frequency, duty cycle, store size, and burst duration.
    if m_sc <= m_sys
        dvL = struct('dV_total_ms',NaN,'feasible',false); return
    end
    m_p = I_bit * n_pulses / (Isp * g0);
    if m_p >= m_sc - m_sys
        dvL = struct('dV_total_ms',NaN,'feasible',false); return
    end
    dvL = struct('dV_total_ms', Isp*g0*log(m_sc/(m_sc-m_p)), 'feasible',true);
end

function v = nan_safe_min(a, b)
% Smaller of a and b, ignoring NaN.
    if isnan(a), v = b; return; end
    if isnan(b), v = a; return; end
    v = min(a, b);
end