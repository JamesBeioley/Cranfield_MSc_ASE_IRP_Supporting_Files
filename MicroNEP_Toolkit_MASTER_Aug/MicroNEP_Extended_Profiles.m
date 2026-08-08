%% =========================================================================
%% MicroNEP_Extended_Profiles.m — Full 35-Profile Mission Landscape
%% =========================================================================
% Dual-constraint feasibility plus requirements analysis across the full
% 35-profile mission set. Extends the 10-profile core in MicroNEP_Model.m
% with Warlock-class, SuperMagdrive-class, and conceptual entries.
%
% Outputs the EXT struct (preserved alongside NEP) and ep struct array
% consumed by MicroNEP_Family_Compare.m.
%
% Profile legend
%   Thruster column:
%     R  Rogue + RTG (this hardware)
%     W  Warlock-class (50 mN, 50 kNs, 3 kg)
%     S  SuperMagdrive-class (1 N, 1 MNs, 75 kg)
%     *  Multiple / class-dependent
%   Category column:
%     E  Evidence-based (independently citable dV)
%     C  Conceptual (derived estimate; no flown precedent)
%     D  Derived (first-principles only; no open citation)
%
% Default power unit per thruster family (as set in variant scripts):
%   Rogue (conf.)   -> RTG (10 We)
%   Rogue (public)  -> RTG (10 We)
%   Warlock         -> RTG+ (40 We)  — best viable single-unit option
%   SuperMagdrive   -> RSG-200 (200 We) — RTG/RTG+ infeasible at this scale
%     Note: SuperMag+RTG+ recharge ~14 hrs vs ~3 min burst; duty <0.1%.
%     RTG+ is architecturally compatible but operationally impractical for
%     SuperMag; RSG-200 is the minimum viable power source.
%
% Run order: Params -> Model -> this script (conventionally before
% Family_Compare, which uses ep for Table 4/4a/4b if present).

if ~exist('NEP','var'), error('Run MicroNEP_Model.m first.'); end

rogue    = NEP.params.rogue;
rtg      = NEP.params.rtg;
rtg_plus = NEP.params.rtg_plus;
rsg      = NEP.params.rsg;
mppt     = NEP.params.mppt;
cfg      = NEP.params.cfg;
g0       = NEP.const.g0;

%% ── A) PROFILE TABLE ────────────────────────────────────────────────────
% Columns: Label | dV_req [m/s] | m_sc [kg] | Thruster | Category | Source
% dV_req is a representative single value; m_sc a representative platform mass.

all_profiles = {
% ── Earth orbits ────────────────────────────────────────────────────────
    'LEO SK / phasing / CA',                10,    50,  'R', 'E', 'Starlink/ESA CA ops practice';
    'VLEO drag comp. (~250-350 km)',        100,   100,  'R', 'E', 'Floberghagen et al. 2011 (GOCE); NRLMSISE-00; Crisp et al. 2020, Prog. Aerosp. Sci.';
    'LEO deorbit (EoL)',                    100,   100,  'R', 'E', 'NASA-STD-8719.14B; Vallado (4th ed.)';
    'LEO high-cadence constellation mgmt',  200,   800,  'W', 'E', 'Warlock; Wertz & Larson 2011';
    'MEO / GNSS SK',                          5,  1000,  'R', 'E', 'ESA Galileo; GPS Block III (Lockheed)';
    'MEO disposal (graveyard raise)',       100,  1000,  'R', 'E', 'IADC-2002-01 (rev. 2007)';
    'GEO stationkeeping (N-S + E-W)',        50,  3000,  'S', 'E', 'SuperMagdrive; Soop 1994; GOES, Intelsat ops';
    'GEO graveyard (EoL raise)',             12,  3000,  'S', 'E', 'SuperMagdrive; IADC-2002-01';
    'Commercial space station (module SK)',   80,    25,  'R', 'E', 'Axiom Station; Starlab (Voyager/Airbus); Vast Haven-1; NASA ISS SK / NASA-STD-3001';
    'Covert / resilient defence satellite', 300,  2000,  '*', 'D', 'Rogue/Warlock; Karpov 2022; Hyperspace Challenge 2024';
% ── GEO co-orbital proximity (merged insp/guardian; B-flavour kept) ─────
    'GEO co-orbital proximity (insp/guardian)', 250,    50,  'R', 'E', 'CORE. Range 100-250 m/s; N-S SK ~50 m/s/yr + patrol (Soop 1994); RPO doctrine; Karpov 2022';
    'Co-orbital inspector (degraded-asset/ISAM)',100,    50,  'R', 'E', 'Docked-sortie inspector; degraded-asset & ISAM-ops inspection; Astroscale ELSA-M; OSAM-1';
% ── Cislunar and lunar ──────────────────────────────────────────────────
    'L1/L2 halo orbit SK',                    3,   100,  'R', 'E', 'JWST ~2.5 m/s/yr; small sentinel scale';
    'SE-L1 space weather sentinel',           3,    50,  'R', 'E', 'CORE. Small in-situ node; CuSP (6U); SWFO-L1/SOLAR-1 suite; AuroraMag; lifetime-bound';
    'NRHO / cislunar relay',                 10,    50,  'R', 'E', 'Zimovan 2017; CAPSTONE 2022';
    'Cislunar comms relay (post-Gateway)',    15,    35,  'R', 'C', 'Zimovan 2017; CAPSTONE 2022; NASA Gateway cancellation (March 2026)';
    'Low lunar orbit (circular polar)',       70,   500,  'R', 'E', 'LRO (Beckman & Lamb 2008); KPLO (Kim 2018)';
    'Frozen lunar orbit (incl. PSR support)', 3,    50,  'R', 'E', 'CORE. Near-polar frozen (Ely&Lieb 2006); PSR support as application; marginal->3x1 stack';
    'Apophis 2029 proximity / companion',    15,    25,  'R', 'C', 'CORE. Prox-ops module (NOT rendezvous; cf RAMSES 1530 m/s); needs Rogue-pub I_bit + RTG+';
% ── Planetary and small bodies ──────────────────────────────────────────
    'Phobos proximity ops',                   8,    50,  'R', 'E', 'Zamaro & Biggs 2016';
    'Asteroid proximity ops',                 2,    25,  'R', 'E', 'Scheeres 2022; Hayabusa2 / OSIRIS-REx';
    'Comet escort',                        1000,  2000,  'S', 'E', 'SuperMagdrive; Rosetta (Accomazzo 2016)';
    'Small-body tourer (multi-target)',    1000,   600,  'S', 'E', 'SuperMagdrive; Dawn (Rayman 2006)';
% ── Deep space and conceptual ───────────────────────────────────────────
    'Titan orbiter',                         40,   200,  'R', 'C', 'Conceptual; Lorenz 2008; Cassini / Dragonfly';
    'Interstellar precursor correction',      1,   100,  'R', 'C', 'Conceptual; Turyshev 2020; McNutt 2019';
    'Icy moon / ocean world orbiter',       100,   150,  'R', 'C', 'Lara 2005; Paskowitz & Scheeres 2006; Lorenz et al. 2008; ESA JUICE (Grasset et al. 2013)';
    'SE-L1 sentinel (DSCOVR-class)',          3,   660,  'R', 'E', 'Flagship variant of core entry 14; DSCOVR/ACE-class 660 kg; deep-space framing';
    'LEO-to-GEO orbit raising',            6000,   500,  'S', 'E', 'SuperMagdrive; Magdrive product page';
    'Cislunar logistics tug (NRHO-LLO)',   3000,   500,  'S', 'E', 'SuperMagdrive; Zimovan 2017';
    'ISAM servicer vehicle',               1000,   500,  '*', 'E', 'Warlock/SM; Astroscale ELSA-M; OSAM-1';
    'Active debris removal (LEO)',          100,   200,  'W', 'E', 'Warlock; ESA ClearSpace-1 / ADRIOS 2020';
    'On-orbit manufacturing platform SK',   100,   200,  'W', 'E', 'Warlock; Varda / Space Forge';
    'Outer solar system cruise trim',        50,   200,  'R', 'E', 'Longhurst (UoM); Betts 2010';
    'Deep-space relay / formation node',    500,   100,  'R', 'C', 'Conceptual; Lizy-Destrez 2019';
    'Distributed aperture swarm',            10,    20,  'R', 'C', 'Conceptual; Fridlund 2010 (Darwin/IRSI); LISA Pathfinder (ESA 2016)';
};
n_all = size(all_profiles, 1);

%% ── THEME ASSIGNMENTS ───────────────────────────────────────────────────
% Five themes, indexed 1-5. Order matches all_profiles rows 1-35.
theme_names = {'Earth Orbit', 'Cislunar & Lunar', ...
               'Planetary & Small Bodies', 'Outer Solar System', ...
               'Logistics & Infrastructure'};
theme_codes = {'EO', 'CL', 'PS', 'OS', 'LG'};
% Row-by-row assignment (post-rework; Apophis at row 20, SE-L1 node at 14):
%   1-12  Earth Orbit (LEO/MEO/GEO/RPO/defence; row 11 = GEO prox CORE)
%   13-19 Cislunar & Lunar (L1/L2, SE-L1, NRHO, LLO, frozen+PSR CORE)
%   20    Planetary & Small Bodies (Apophis CORE — planetary defence)
%   21-23 Planetary & Small Bodies (Phobos, asteroid, comet, tourer)
%   24-26 Outer Solar System (Titan, interstellar, icy moon)
%   27    Cislunar & Lunar (SE-L1 DSCOVR-class flagship variant)
%   28-32 Logistics & Infrastructure (orbit raise, tug, ISAM, ADR, mfg)
%   33-34 Outer Solar System (cruise trim, deep-space relay)
%   35    Earth Orbit (distributed aperture swarm — LEO)
theme_ids = [1,1,1,1,1,1,1,1,1,1,1,1, ...   %  1-12  Earth Orbit
             2,2,2,2,2,2, ...                % 13-18  Cislunar & Lunar (L1/L2,SE-L1,NRHO,comms,LLO,frozen+PSR)
             3, ...                          % 19     Apophis (Planetary & Small Bodies)
             3,3,3,3, ...                    % 20-23  Planetary & Small Bodies (Phobos,asteroid,comet,tourer)
             4,4,4, ...                      % 24-26  Outer Solar System (Titan,interstellar,icy moon)
             2, ...                          % 27     Cislunar (SE-L1 DSCOVR-class)
             5,5,5,5,5, ...                 % 28-32  Logistics & Infrastructure
             4,4, ...                        % 33-34  Outer Solar System
             1];                             % 35     Earth Orbit (swarm)

%% ── B) FEASIBILITY AND REQUIREMENTS ─────────────────────────────────────
rc_max      = NEP.rc_max;
rc_max_plus = NEP.rc_max_plus;   % RTG+ duty ceiling (40 We, same store/burst)
spy         = 365.25 * 86400;

ep = struct('label','','dV_req_ms',0,'m_sc_kg',0,'thruster','','category','', ...
    'source','','dV_duty_max_ms',0,'dV_duty_plus_ms',0, ...
    'dV_life_1M_ms',0,'dV_life_10M_ms',0, ...
    'feasible_duty',false,'feasible_duty_plus',false, ...
    'feasible_1M',false,'feasible_10M',false,'feasible_10M_plus',false, ...
    'I_total_req_Ns',0,'N_req_at_nom_M',0,'I_req_at_10M_uNs',0,'tier',0, ...
    'theme_id',0,'theme_str','','theme_code','');
ep = repmat(ep, n_all, 1);

for i = 1:n_all
    dV_req = all_profiles{i,2};
    m_sc   = all_profiles{i,3};

    dvL_1M  = dv_lifetime_local(rogue.I_bit_Ns, rogue.n_pulses_design,   m_sc, cfg.m_prop_sys_kg, rogue.Isp_s, g0);
    dvL_10M = dv_lifetime_local(rogue.I_bit_Ns, rogue.n_pulses_ambition, m_sc, cfg.m_prop_sys_kg, rogue.Isp_s, g0);

    dV_duty_i      = rogue.F_baseline_N * rc_max.duty_cycle      * spy / m_sc;
    dV_duty_plus_i = rogue.F_baseline_N * rc_max_plus.duty_cycle * spy / m_sc;
    duty_ok        = dV_duty_i      >= dV_req;
    duty_ok_plus   = dV_duty_plus_i >= dV_req;

    m_prop_req  = m_sc * (1 - exp(-dV_req / (rogue.Isp_s * g0)));
    I_total_req = m_prop_req * rogue.Isp_s * g0;
    N_req_nom   = I_total_req / rogue.I_bit_Ns;
    I_req_10M   = I_total_req / rogue.n_pulses_ambition;

    tier = numel(cfg.req_tiers_Ns) + 1;
    for t = 1:numel(cfg.req_tiers_Ns)
        if I_total_req <= cfg.req_tiers_Ns(t), tier = t; break; end
    end

    ep(i).label              = all_profiles{i,1};
    ep(i).dV_req_ms          = dV_req;
    ep(i).m_sc_kg            = m_sc;
    ep(i).thruster           = all_profiles{i,4};
    ep(i).category           = all_profiles{i,5};
    ep(i).source             = all_profiles{i,6};
    ep(i).dV_duty_max_ms     = dV_duty_i;
    ep(i).dV_duty_plus_ms    = dV_duty_plus_i;
    ep(i).dV_life_1M_ms      = dvL_1M;
    ep(i).dV_life_10M_ms     = dvL_10M;
    ep(i).feasible_duty      = duty_ok;
    ep(i).feasible_duty_plus = duty_ok_plus;
    ep(i).feasible_1M        = duty_ok      && (dvL_1M  >= dV_req);
    ep(i).feasible_10M       = duty_ok      && (dvL_10M >= dV_req);
    ep(i).feasible_10M_plus  = duty_ok_plus && (dvL_10M >= dV_req);
    ep(i).I_total_req_Ns     = I_total_req;
    ep(i).N_req_at_nom_M     = N_req_nom / 1e6;
    ep(i).I_req_at_10M_uNs  = I_req_10M * 1e6;
    ep(i).tier               = tier;
    ep(i).theme_id           = theme_ids(i);
    ep(i).theme_str          = theme_names{theme_ids(i)};
    ep(i).theme_code         = theme_codes{theme_ids(i)};
end

%% ── C) FEASIBILITY SCREEN ───────────────────────────────────────────────
% Profiles closed by total impulse only. Duty ceiling is not screened in
% this table; for the dual-constraint check including duty, see Table 1
% above (per profile) or Section 4 of MicroNEP_Summary.m (10-profile core).
I_req_all = arrayfun(@(x) x.I_total_req_Ns, ep);

screen.n_pulse_cols   = [1e6, 10e6, 50e6];
screen.n_rogue_rows   = [1, 3, 5];
screen.row_labels     = {'Rogue x1 (demo)', 'Rogue x3 (demo)', 'Rogue x5 (demo)'};
screen.n_closed       = zeros(numel(screen.n_rogue_rows), numel(screen.n_pulse_cols));
for r = 1:numel(screen.n_rogue_rows)
    for c = 1:numel(screen.n_pulse_cols)
        I_del = screen.n_rogue_rows(r) * rogue.I_bit_Ns * screen.n_pulse_cols(c);
        screen.n_closed(r,c) = sum(I_del >= I_req_all);
    end
end
screen.I_pub_Ns         = 3000;   % Rogue 3 public total impulse
screen.n_closed_pub     = sum(screen.I_pub_Ns >= I_req_all);

% Class and tier counts.
counts.by_class.R     = sum(strcmp({ep.thruster},'R'));
counts.by_class.W     = sum(strcmp({ep.thruster},'W'));
counts.by_class.S     = sum(strcmp({ep.thruster},'S'));
counts.by_class.multi = sum(strcmp({ep.thruster},'*'));
counts.by_tier        = zeros(1, numel(cfg.req_tiers_Ns) + 1);
tiers_all             = [ep.tier];
for t = 1:numel(cfg.req_tiers_Ns)
    counts.by_tier(t) = sum(tiers_all == t);
end
counts.by_tier(end)   = sum(tiers_all > numel(cfg.req_tiers_Ns));

EXT.profiles  = ep;
EXT.n_all     = n_all;
EXT.screen    = screen;
EXT.counts    = counts;
EXT.I_req_all_Ns = I_req_all;

%% ── D) CONSOLE TABLES ───────────────────────────────────────────────────
% Profiles in the Model/Summary 10-core are marked with '*' in the tag column.
core_labels = { ...
    'Asteroid proximity ops', ...
    'Frozen lunar orbit (incl. PSR support)', ...
    'VLEO drag comp. (~250-350 km)', ...
    'NRHO / cislunar relay', ...
    'L1/L2 halo orbit SK', ...
    'Phobos proximity ops', ...
    'GEO co-orbital proximity (insp/guardian)', ...
    'Icy moon / ocean world orbiter', ...
    'SE-L1 space weather sentinel', ...
    'Apophis 2029 proximity / companion'};

fprintf('\nExtended profile set - 35 profiles  (I_bit = %.0f uN.s, Isp = %.0f s)\n', ...
    rogue.I_bit_Ns*1e6, rogue.Isp_s);
fprintf('  Thr: R Rogue+RTG | W Warlock | S SuperMagdrive | * Multiple\n');
fprintf('  Cat: E Evidence-based | C Conceptual | D Derived\n');
fprintf('  Thm: EO Earth Orbit | CL Cislunar & Lunar | PS Planetary & Small Bodies\n');
fprintf('       OS Outer Solar System | LG Logistics & Infrastructure\n');
fprintf('  # = row index (matches F2 scatter labels)  |  * = core 10 profile\n');

% Table 1 — dual-constraint feasibility
fprintf('\nTable 1 - Dual-constraint feasibility (single Rogue + RTG, design power)\n');
fprintf('  %3s %-40s | %-3s | %-3s | %-3s | %5s | %5s | %12s | %10s | %5s | %5s\n', ...
    '#*', 'Profile', 'Thm', 'Thr', 'Cat', 'dV', 'm_sc', 'Duty ceil.', 'dV @ 1M', 'F@1M', 'F@10M');
fprintf('  %3s %-40s | %-3s | %-3s | %-3s | %5s | %5s | %12s | %10s | %5s | %5s\n', ...
    '', '', '', '', '', 'm/s', 'kg', '[m/s/yr]', '[m/s, tot.]', '', '');
fprintf('  %s\n', repmat('-', 1, 118));
for i = 1:n_all
    e   = ep(i);
    tag = ' '; if any(strcmp(e.label, core_labels)), tag = '*'; end
    fprintf('  %2d%s %-40s | %-3s | %-3s | %-3s | %5.0f | %5.0f | %12.1f | %10s | %5s | %5s\n', ...
        i, tag, e.label, e.theme_code, e.thruster, e.category, e.dV_req_ms, e.m_sc_kg, ...
        e.dV_duty_max_ms, fmt_dv(e.dV_life_1M_ms), yn(e.feasible_1M), yn(e.feasible_10M));
    if any(i == [9, 15, 19, 23, 28]), fprintf('\n'); end
end

% Table 2 — requirements analysis
fprintf('\nTable 2 - Requirements analysis (total impulse, pulse budget, tier)\n');
fprintf('  %3s %-40s | %-3s | %10s | %10s | %12s | %4s\n', ...
    '#*', 'Profile', 'Thm', 'I_req [Ns]', 'N_req [M]', 'I_req@10M', 'Tier');
fprintf('  %3s %-40s | %-3s | %10s | %10s | %12s | %4s\n', ...
    '', '', '', '', '@ baseline', '[uN.s]', '');
fprintf('  %s\n', repmat('-', 1, 97));
for i = 1:n_all
    e   = ep(i);
    tag = ' '; if any(strcmp(e.label, core_labels)), tag = '*'; end
    if e.tier > numel(cfg.req_tiers_Ns), tier_s = '>T3'; else, tier_s = sprintf('T%d', e.tier); end
    fprintf('  %2d%s %-40s | %-3s | %10.0f | %10.1f | %12.1f | %4s\n', ...
        i, tag, e.label, e.theme_code, e.I_total_req_Ns, e.N_req_at_nom_M, ...
        e.I_req_at_10M_uNs, tier_s);
    if any(i == [9, 15, 19, 23, 28]), fprintf('\n'); end
end

% Table 3 — feasibility screen
fprintf('\nTable 3 - Feasibility screen (profiles closed vs n_Rogue x pulse budget)\n');
fprintf('  I_bit %.0f uN.s. n_RTG omitted (orthogonal). Duty ceiling not screened (impulse-only).\n', rogue.I_bit_Ns*1e6);
fprintf('  %-22s |', 'Configuration');
for c = 1:numel(screen.n_pulse_cols)
    fprintf('  %5s pulses |', sprintf('%.0fM', screen.n_pulse_cols(c)/1e6));
end
fprintf('\n  %s\n', repmat('-', 1, 22 + numel(screen.n_pulse_cols)*16));
for r = 1:numel(screen.n_rogue_rows)
    fprintf('  %-22s |', screen.row_labels{r});
    for c = 1:numel(screen.n_pulse_cols)
        fprintf('    %2d / %2d      |', screen.n_closed(r,c), n_all);
    end
    fprintf('\n');
end
fprintf('  %s\n', repmat('-', 1, 22 + numel(screen.n_pulse_cols)*16));
fprintf('  %-22s |    %2d / %2d  *  (all pulse columns)\n', ...
    'Rogue x1 (public)', screen.n_closed_pub, n_all);
fprintf('  * Delivered impulse fixed at the 3000 Ns public spec (= 30M pulses\n');
fprintf('    at 100 uN.s); closure is independent of the pulse budget columns.\n');

% Summary counts
fprintf('\nSummary counts\n');
fprintf('  By assumed class:  R %d  |  W %d  |  S %d  |  Multiple %d\n', ...
    counts.by_class.R, counts.by_class.W, counts.by_class.S, counts.by_class.multi);
fprintf('  By requirement tier:\n');
for t = 1:numel(cfg.req_tiers_Ns)
    fprintf('    %s (<= %.0f Ns): %d profiles\n', ...
        cfg.req_tier_labels{t}, cfg.req_tiers_Ns(t), counts.by_tier(t));
end
fprintf('    Beyond Tier 3 (> %.0f Ns): %d profiles\n', ...
    cfg.req_tiers_Ns(end), counts.by_tier(end));

%% ── E) COMPETITOR EP SYSTEMS — RTG-PAIRING SCREEN ───────────────────────
% Minimum RTG / RTG+ unit count to supply nominal input power for each
% competitor system. Regime classification:
%   R1  Stored-energy: 1 RTG sufficient; peak pulse power decoupled by supercap.
%   R2  Low-power continuous (~12-40 W): 1-2 RTG+ units.
%   R3  High-power continuous (>40 W): requires multiple RTG+.
%
% Sources:
%   ThrustMe NPT30-I2  : thrustme.fr product page; Rafalskyi et al. 2021
%   Enpulsion NANO R3  : Enpulsion/Satsearch datasheet; ~40 W nom, 1.42 kg
%   Busek BIT-3 Gen 2  : Busek datasheet; 56-75 W, 1.40 kg, ~7.5 kNs
%   Enpulsion MICRO R3 : Satsearch datasheet; 90-100 W nom, 3.9 kg wet
%   Xantus (BSS)       : Benchmark Space Systems datasheet Apr 2026;
%                        80 W nom, 1.4 kg, 2 kNs demonstrated;
%                        metal-propellant PPT (stored-energy — Rogue analogue)
%   SPT-140            : Fakel/Busek datasheet; ~4500 W nom, ~8.0 kg
%   NEXT-C             : NASA GRC; 7400 W max, ~13.5 kg thruster

cmp.name = { ...
    'Rogue demo', 'Rogue pub.', 'Warlock', ...
    'ThrustMe NPT30-I2',     'Enpulsion NANO R3', ...
    'Busek BIT-3 Gen2',      'Busek BET-MAX', ...
    'Enpulsion MICRO R3',    'Enpulsion NEXUS', ...
    'Xantus (BSS)', ...
    'SPT-140',               'NEXT-C'              }';

% Per-thruster data: [P_nom_W, m_thr_kg, I_total_Ns, Isp_s, stored_E_bool]
% I_total NaN = not specified / propellant-load dependent at vehicle scale.
% P_nom for stored-energy systems (R1: Rogue, Warlock, Xantus) is the PPU
% rated/nominal operating power — NOT the average RTG sip (9.2 W). Using
% the PPU power gives a fair alpha comparison across all architectures.
% Rogue public: 100 W PPU (Magdrive product page). Warlock: 150 W PPU.
cmp_data = [ ...
%  P_nom   m_thr   I_total   Isp   stored_E
  100.0,   3.05,    120,    1800,   1;   % Rogue demo   (PPU 100 W; 12 uN.s x 10M)
  100.0,   3.05,   3000,    1800,   1;   % Rogue public (PPU 100 W; 100 uN.s x 30M)
  150.0,   3.00,  50000,    2500,   1;   % Warlock (PPU 150 W)
   40.0,   1.42,   5500,    1800,   0;   % ThrustMe NPT30-I2 (1U)
   40.0,   1.42,   5000,    4000,   0;   % Enpulsion NANO R3
   75.0,   1.40,   7500,    2150,   0;   % Busek BIT-3 Gen2
   12.0,   0.80,    360,     850,   0;   % Busek BET-MAX (4x BET-300-P; 12 W sys nom; 4x90 Ns Config A dem.)
  100.0,   3.90,  26000,    4000,   0;   % Enpulsion MICRO R3 (nominal; Enpulsion website)
  100.0,   4.90,  30000,    2000,   0;   % Enpulsion NEXUS (100 W nom; 30 kNs; 50-150 W range)
   80.0,   1.40,   2000,    2500,   1;   % Xantus BSS (metal PPT — stored-E)
 4500.0,   8.00,    NaN,    1800,   0;   % SPT-140
 7400.0,  13.50,    NaN,    4190,   0;   % NEXT-C
];

cmp.P_nom_W    = cmp_data(:,1);
cmp.m_thr_kg   = cmp_data(:,2);
cmp.I_total_Ns = cmp_data(:,3);
cmp.Isp_s      = cmp_data(:,4);
cmp.stored_E   = logical(cmp_data(:,5));

% Net power from each source after MPPT / power conditioning.
% RTG and RTG+: subtract parasitic (heater control, housekeeping).
% RSG: electrical output already net; MPPT applies at ~92%.
P_net_RTG   = rtg.P_design_W    * mppt.eta - rtg.P_parasitic_W;   % ~9.19 W
P_net_RTGp  = rtg_plus.P_design_W * mppt.eta - rtg.P_parasitic_W; % ~36.79 W
P_net_RSG35 = rsg(1).P_design_W * mppt.eta;                       % ~32.2 W

n_cmp = numel(cmp.name);
cmp.n_RTG    = zeros(n_cmp,1);
cmp.n_RTGp   = zeros(n_cmp,1);
cmp.n_RSG35  = zeros(n_cmp,1);
cmp.m_RTG_kg = zeros(n_cmp,1);    % total power-source mass (RTG baseline)
cmp.m_RTGp_kg= zeros(n_cmp,1);    % total power-source mass (RTG+)
cmp.m_sys_RTG_kg  = zeros(n_cmp,1);
cmp.m_sys_RTGp_kg = zeros(n_cmp,1);
cmp.alpha_RTG_kgWe  = zeros(n_cmp,1);
cmp.alpha_RTGp_kgWe = zeros(n_cmp,1);

for k = 1:n_cmp
    if cmp.stored_E(k)
        % Stored-energy: 1 RTG charges the store; peak pulse power irrelevant.
        nr = 1;  nrp = 1;  nrs = 1;
    else
        nr  = ceil(cmp.P_nom_W(k) / P_net_RTG);
        nrp = ceil(cmp.P_nom_W(k) / P_net_RTGp);
        nrs = ceil(cmp.P_nom_W(k) / P_net_RSG35);
    end
    cmp.n_RTG(k)   = nr;
    cmp.n_RTGp(k)  = nrp;
    cmp.n_RSG35(k) = nrs;
    cmp.m_RTG_kg(k)       = nr  * rtg.mass_kg;
    cmp.m_RTGp_kg(k)      = nrp * rtg_plus.mass_kg;
    cmp.m_sys_RTG_kg(k)   = cmp.m_thr_kg(k) + cmp.m_RTG_kg(k);
    cmp.m_sys_RTGp_kg(k)  = cmp.m_thr_kg(k) + cmp.m_RTGp_kg(k);
    cmp.alpha_RTG_kgWe(k)  = cmp.m_sys_RTG_kg(k)  / cmp.P_nom_W(k);
    cmp.alpha_RTGp_kgWe(k) = cmp.m_sys_RTGp_kg(k) / cmp.P_nom_W(k);
end

% Total impulse per system mass [Ns/kg] — architecture-neutral performance
% metric. NaN where I_total is not specified (SPT-140, NEXT-C).
cmp.Ins_per_kg_RTG  = cmp.I_total_Ns ./ cmp.m_sys_RTG_kg;    % with baseline RTG
cmp.Ins_per_kg_RTGp = cmp.I_total_Ns ./ cmp.m_sys_RTGp_kg;   % with RTG+
cmp.regime = cell(n_cmp,1);
for k = 1:n_cmp
    if cmp.stored_E(k)
        cmp.regime{k} = 'R1  stored-energy';
    elseif cmp.n_RTGp(k) <= 2
        cmp.regime{k} = 'R2  low-pwr cont.';
    else
        cmp.regime{k} = 'R3  high-pwr cont.';
    end
end

EXT.cmp = cmp;   % append to EXT struct

% ── Console output ────────────────────────────────────────────────────────
fprintf('\nSection E — Competitor EP-RTG pairing screen\n');
fprintf('  Source net power:  RTG %.1f W | RTG+ %.1f W | RSG-35 %.0f W\n', ...
    P_net_RTG, P_net_RTGp, P_net_RSG35);
fprintf('  Source unit mass:  RTG %.1f kg | RTG+ %.1f kg | RSG-35 %.1f kg\n', ...
    rtg.mass_kg, rtg_plus.mass_kg, rsg(1).mass_kg);
fprintf('  P_nom for R1 (stored-energy) = PPU rated power; for R2/R3 = continuous input.\n\n');
fprintf('  %-26s | %5s | %5s | %5s | %7s | %7s | %6s | %7s | %8s | %8s | %-18s\n', ...
    'Thruster', 'Pnom', 'nRTG', 'nRTG+', 'mS.RTG', 'mS.RTG+', 'a.RTG', 'a.RTG+', ...
    'I/m.RTG', 'I/m.RTG+', 'Regime');
fprintf('  %-26s | %5s | %5s | %5s | %7s | %7s | %6s | %7s | %8s | %8s | %-18s\n', ...
    repmat('-',1,26), '[W]', '--', '--', '[kg]', '[kg]', '[kg/W]', '[kg/W]', '[Ns/kg]', '[Ns/kg]', '--');
for k = 1:n_cmp
    im_rtg  = cmp.Ins_per_kg_RTG(k);
    im_rtgp = cmp.Ins_per_kg_RTGp(k);
    if isnan(im_rtg),  s_rtg  = '     N/A'; else, s_rtg  = sprintf('%8.0f', im_rtg);  end
    if isnan(im_rtgp), s_rtgp = '     N/A'; else, s_rtgp = sprintf('%8.0f', im_rtgp); end
    fprintf('  %-26s | %5.0f | %5d | %5d | %7.1f | %7.1f | %6.3f | %7.3f | %8s | %8s | %-18s\n', ...
        cmp.name{k}, cmp.P_nom_W(k), cmp.n_RTG(k), cmp.n_RTGp(k), ...
        cmp.m_sys_RTG_kg(k), cmp.m_sys_RTGp_kg(k), ...
        cmp.alpha_RTG_kgWe(k), cmp.alpha_RTGp_kgWe(k), ...
        s_rtg, s_rtgp, cmp.regime{k});
end
fprintf('  SPT-140: %d RTGs (%.0f kg); NEXT-C: %d RTGs (%.0f kg) — excluded from F1 plot.\n\n', ...
    cmp.n_RTG(strcmp(cmp.name,'SPT-140')), cmp.m_RTG_kg(strcmp(cmp.name,'SPT-140')), ...
    cmp.n_RTG(strcmp(cmp.name,'NEXT-C')), cmp.m_RTG_kg(strcmp(cmp.name,'NEXT-C')));


%% ── F) LANDSCAPE PLOTS ───────────────────────────────────────────────────
% Plot F1 — Competitor EP: system mass vs total impulse (log-log).
%   All Magdrive systems (name contains 'Rogue' or 'Warlock'): family blue.
%   Each competitor: individual colour, looked up by name.
%   Symbols encode regime: d=R1 stored-energy | o=R2 low-pwr | s=R3 high-pwr.
%   Open marker = baseline RTG; filled = RTG+ (R2/R3; connected by line).
%   SPT-140 / NEXT-C excluded: I_total unspecified; mass with baseline
%   RTG (6-10 t) would destroy the y-axis scale.
% Plot F2 — All-35 profiles: dV vs total impulse required (log-log).

cmp_ok = isfinite(cmp.I_total_Ns);
clr_magdrive = [0.20 0.40 0.70];     % family blue (fam_colors(1,:) in Plots.m)

% Per-label position: edit the second column to reposition any label.
% Codes: 'r'=right (default) | 'l'=left | 't'=above | 'b'=below.
% All offsets use the same standard distance; only direction changes.
lbl_pos_map = { ...
    'Rogue demo',  'r'; ...
    'Rogue pub.',  'r'; ...
    'Warlock',     't'; ...
    'ThrustMe NPT30-I2',      'r'; ...
    'Enpulsion NANO R3',      'l'; ...
    'Busek BIT-3 Gen2',       'r'; ...
    'Enpulsion MICRO R3',     'l'; ...
    'Xantus (BSS)',           'l'; ...
};

figure('Name','Competitor system mass'); hold on; grid on;
for k = 1:numel(cmp.name)
    if ~cmp_ok(k), continue; end
    nm_k = cmp.name{k};

    % Colour: Magdrive family blue; each competitor its own colour.
    if contains(nm_k,'Rogue') || contains(nm_k,'Warlock'), clrk = clr_magdrive;
    elseif contains(nm_k,'ThrustMe'),         clrk = [0.85 0.40 0.10];
    elseif strcmp(nm_k,'Enpulsion NANO R3'),  clrk = [0.10 0.65 0.30];
    elseif contains(nm_k,'BIT-3'),            clrk = [0.75 0.15 0.15];
    elseif contains(nm_k,'BET-MAX'),          clrk = [0.75 0.15 0.15];
    elseif strcmp(nm_k,'Enpulsion MICRO R3'), clrk = [0.55 0.10 0.65];
    elseif strcmp(nm_k,'Enpulsion NEXUS'),    clrk = [0.00 0.55 0.65];
    elseif contains(nm_k,'Xantus'),           clrk = [0.30 0.60 0.70];
    else,                                     clrk = [0.50 0.50 0.50];
    end

    % Regime symbol
    switch strtok(cmp.regime{k})
        case 'R1', mk = 'd';
        case 'R2', mk = 'o';
        otherwise, mk = 's';
    end

    % Plot marker(s)
    if cmp.stored_E(k)
        scatter(cmp.I_total_Ns(k), cmp.m_sys_RTG_kg(k), 90, clrk, mk, 'filled', ...
            'HandleVisibility','off');
    else
        scatter(cmp.I_total_Ns(k), cmp.m_sys_RTG_kg(k),  55, clrk, mk, ...
            'LineWidth',1.3,'HandleVisibility','off');
        scatter(cmp.I_total_Ns(k), cmp.m_sys_RTGp_kg(k), 55, clrk, mk, 'filled', ...
            'HandleVisibility','off');
        plot([cmp.I_total_Ns(k) cmp.I_total_Ns(k)], ...
             [cmp.m_sys_RTG_kg(k) cmp.m_sys_RTGp_kg(k)], ...
             '-','Color',clrk,'LineWidth',0.8,'HandleVisibility','off');
    end

    % Label position — look up by name; default 'r' if not in map.
    pos_idx = find(strcmp(lbl_pos_map(:,1), nm_k), 1);
    if ~isempty(pos_idx), lbl_p = lbl_pos_map{pos_idx,2}; else, lbl_p = 'r'; end
    switch lbl_p
        case 'r', xl=cmp.I_total_Ns(k)*1.07; yl=cmp.m_sys_RTG_kg(k);    ha='left';   va='middle';
        case 'l', xl=cmp.I_total_Ns(k)*0.93; yl=cmp.m_sys_RTG_kg(k);    ha='right';  va='middle';
        case 't', xl=cmp.I_total_Ns(k);       yl=cmp.m_sys_RTG_kg(k)*1.2; ha='center'; va='bottom';
        case 'b', xl=cmp.I_total_Ns(k);       yl=cmp.m_sys_RTG_kg(k)*0.83; ha='center'; va='top';
    end
    text(xl, yl, nm_k, 'FontSize',10,'Color',clrk,'Interpreter','none',...
        'HorizontalAlignment',ha,'VerticalAlignment',va);
end
lgc = [0.35 0.35 0.35];
scatter(nan,nan,65,clr_magdrive,'d','filled','DisplayName','Magdrive family');
scatter(nan,nan,70,lgc,'d','filled','DisplayName','R1: stored-energy');
scatter(nan,nan,55,lgc,'o','LineWidth',1.3,'DisplayName','R2: low-pwr continuous  (open=RTG / filled=RTG+)');
scatter(nan,nan,55,lgc,'s','LineWidth',1.3,'DisplayName','R3: high-pwr continuous  (open=RTG / filled=RTG+)');
set(gca,'XScale','log','FontSize',11);
xlim([1e2 1e5]);
xlabel('Total impulse [Ns]'); ylabel('System mass [kg]');
title('Competitor EP systems - system mass vs total impulse (RTG-paired)');
legend('Location','northwest','FontSize',11);

I_req_v  = [EXT.profiles.I_total_req_Ns];
dv_req_v = [EXT.profiles.dV_req_ms];
theme_v  = [EXT.profiles.theme_id];

% Theme colours: EO | CL | PS | OS | LG
tc_th = [0.20 0.45 0.72;   % 1  Earth Orbit           -- steel blue
         0.50 0.55 0.62;   % 2  Cislunar & Lunar       -- slate grey
         0.88 0.55 0.14;   % 3  Planetary & Sm. Bodies -- warm amber
         0.50 0.18 0.62;   % 4  Outer Solar System     -- deep violet
         0.12 0.58 0.50];  % 5  Logistics & Infra.     -- teal
th_lbl = {'Earth Orbit','Cislunar & Lunar', ...
          'Planetary & Small Bodies','Outer Solar System', ...
          'Logistics & Infrastructure'};

% DD index lookup (ring highlights and bold labels)
dd_lbl_f2 = {'GEO co-orbital proximity (insp/guardian)','VLEO drag comp. (~250-350 km)'...
             'Apophis 2029 proximity / companion','Asteroid proximity ops','Icy moon / ocean world orbiter'};
dd_idxs = zeros(1, numel(dd_lbl_f2));
for i = 1:numel(dd_lbl_f2)
    idx = find(strcmp({EXT.profiles.label}, dd_lbl_f2{i}), 1);
    if ~isempty(idx), dd_idxs(i) = idx; end
end

% Core-10 index lookup (square outline highlight). DD set is a subset of core.
core_idxs = find(ismember({EXT.profiles.label}, core_labels));

figure('Name','All-35 mission scatter'); hold on; grid on;
yline(rogue.I_bit_Ns*rogue.n_pulses_ambition,'--','Color',[.55 .55 .55],...
    'Label','Rogue conf.','FontSize',11,'LabelHorizontalAlignment','right',...
    'HandleVisibility','off');
yline(3000, '--','Color',[.20 .60 .90],'Label','Rogue pub.','FontSize',10,...
    'LabelHorizontalAlignment','right','HandleVisibility','off');
yline(50000,'--','Color',[.90 .50 .10],'Label','Warlock','FontSize',10,...
    'LabelHorizontalAlignment','right','HandleVisibility','off');
yline(1e6,  '--','Color',[.70 .20 .80],'Label','SuperMag','FontSize',10,...
    'LabelHorizontalAlignment','right','HandleVisibility','off');

% Theme-coloured dots
for t = 1:5
    scatter(dv_req_v(theme_v==t), I_req_v(theme_v==t), 75, tc_th(t,:), 'filled',...
        'MarkerFaceAlpha', 0.80, 'DisplayName', th_lbl{t});
end

% Number label positions — edit entries to reposition individual labels.
%   'r' right (default) | 'l' left | 't' above | 'b' below
%   Index matches profile row numbers in Tables 1 & 2.
%   NB rows 19 (Apophis) and 20 (Phobos) nearly coincide in (dV,I_req):
%   Apophis pushed 't' (above), Phobos 'b' (below) to de-collide.
num_lbl_pos = { ...
    'r','l','r','r','r','r','r','r','r', ...   %  1- 9
    'r','r','r','r','l','t','r','l','r', ...   % 10-18
    't','b','r','r','l','l','r','r','r', ...   % 19-27  (19 Apophis 't', 20 Phobos 'b')
    'r','r','r','l','t','r','r','r' };         % 28-35

% Number labels: bold black for DD missions, small tinted for all others
for i = 1:n_all
    t = theme_v(i);
    switch num_lbl_pos{i}
        case 'r', xl=dv_req_v(i)*1.12; yl=I_req_v(i);      ha='left';   va='middle';
        case 'l', xl=dv_req_v(i)*0.88; yl=I_req_v(i);      ha='right';  va='middle';
        case 't', xl=dv_req_v(i);      yl=I_req_v(i)*1.20; ha='center'; va='bottom';
        case 'b', xl=dv_req_v(i);      yl=I_req_v(i)*0.80; ha='center'; va='top';
    end
    if any(dd_idxs == i)
        text(xl, yl, num2str(i), 'FontSize',10, 'FontWeight','bold', 'Color',[0 0 0],...
            'HorizontalAlignment',ha, 'VerticalAlignment',va);
    else
        text(xl, yl, num2str(i), 'FontSize',10, 'FontWeight','normal', 'Color',tc_th(t,:)*0.65,...
            'HorizontalAlignment',ha, 'VerticalAlignment',va);
    end
end

% Core-10 highlight: hollow square outline (slightly larger than dot)
for i = 1:numel(core_idxs)
    k = core_idxs(i);
    scatter(dv_req_v(k), I_req_v(k), 150, [0.15 0.15 0.15], 's',...
        'LineWidth', 1.3, 'HandleVisibility','off');
end

% DD highlight: hollow black circle (largest), over the core square
for i = 1:numel(dd_idxs)
    if dd_idxs(i) == 0, continue; end
    scatter(dv_req_v(dd_idxs(i)), I_req_v(dd_idxs(i)), 230, 'k', 'o',...
        'LineWidth', 2.0, 'HandleVisibility','off');
end

% Legend proxies suppressed: core/DD highlight meaning is stated in the title.
% (squares = core 10; circles = deep dives)

set(gca,'XScale','log','YScale','log','FontSize',11);
xlim([1e0 1e4]); ylim([1e1 1e7]);
xlabel('\DeltaV required [m/s]'); ylabel('I_{total} required [Ns]');
title('All 35 mission profiles -- \DeltaV vs total impulse  (squares = core 10; circles = deep dives)');
legend('Location','northwest','FontSize',11);

%% ── G) LOAD MESSAGE ─────────────────────────────────────────────────────
fprintf('MicroNEP_Extended_Profiles complete.\n');
fprintf('  ep struct populated with %d profiles. Structured data in EXT.{profiles, screen, counts, cmp}.\n\n', n_all);

%% ── LOCAL FUNCTIONS ─────────────────────────────────────────────────────

function dV = dv_lifetime_local(I_bit, n_pulses, m_sc, m_sys, Isp, g0)
% Mirrors MicroNEP_Model.m's delta_v_lifetime (MATLAB scoping). The
% propellant-overrun case returns NaN (infeasible), matching Model so the
% downstream feasibility tests (dV >= dV_req) agree across scripts.
    if m_sc <= m_sys, dV = NaN; return; end
    m_p = I_bit * n_pulses / (Isp * g0);
    if m_p >= m_sc - m_sys, dV = NaN; return; end
    dV = Isp * g0 * log(m_sc / (m_sc - m_p));
end

function s = fmt_dv(v)
% NaN covers both mass-infeasible and propellant-overrun cases (see
% dv_lifetime_local); Inf branch retained defensively.
    if isnan(v),     s = 'N/A';
    elseif isinf(v), s = '>prop';
    else,            s = sprintf('%.2f', v);
    end
end

function s = yn(tf)
    if tf, s = 'YES'; else, s = 'NO'; end
end