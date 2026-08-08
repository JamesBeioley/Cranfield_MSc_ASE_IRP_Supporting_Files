%% =========================================================================
%% MicroNEP_Deep_Dives.m — Mission Deep-Dive Back-Solve Analysis
%% =========================================================================
% Determines in higher fidelity the total impulse, pulse budget, and
% specific-mass requirements needed to close five selected deep-dive
% missions. Approach is requirements-first: given (m_sc, dV_total, ops
% lifetime), back-solve the exact (I_total, N_pulses, alpha) thresholds,
% then map each to the first Magdrive / PA hardware configuration that
% closes it. This defines the development envelope for bid proposals.
%
% Five missions (reworked Jun 2026; PSR folded into core frozen-lunar):
%   DD1 — GEO co-orbital proximity (insp/guardian) (Commercial/Defence)
%         sub-concepts: (A) persistent free-flyer; (B) docked sortie inspector
%   DD2 — VLEO drag compensation            (Earth Orbit)
%   DD3 — Apophis 2029 proximity / companion (Planetary Defence — NEW)
%   DD4 — Asteroid proximity ops            (Science — deep)
%   DD5 — Icy moon / ocean world orbiter    (Science — deep/outer)
%
% Run order:
%   1. MicroNEP_Params.m
%   2. MicroNEP_Model.m              -> NEP
%   3. MicroNEP_Rogue_Public.m       -> NEP_RP
%   4. MicroNEP_Warlock.m            -> NEP_W
%   5. MicroNEP_SuperMag.m           -> NEP_SM
%   6. MicroNEP_Extended_Profiles.m  -> EXT
%   7. MicroNEP_Family_Compare.m
%   8. MicroNEP_Deep_Dives.m  (this) -> dd
%
% Outputs: dd struct (array of 5, one per mission); also printed to console.
%
% References / ΔV sources per mission — see individual mission blocks.
%% =========================================================================

%% ── A) MISSION DEFINITIONS ───────────────────────────────────────────────
% Each mission is defined by a mass range [lo, nom, hi] kg, a ΔV range
% [lo, nom, hi] m/s (representative total over the stated ops lifetime),
% and an ops lifetime in years.
%
% ΔV values are representative totals — not worst-case budgets.
% Back-solve uses the nominal point; lo/hi give sensitivity bounds.

missions(1).label      = 'GEO proximity operations (inspector / guardian)';
missions(1).theme      = 'Commercial / Defence';
missions(1).m_sc_kg    = [25, 50, 100];   % lo / nom / hi  [kg]
missions(1).dV_ms      = [100, 250, 500]; % guardian bounding case; inspector subset: [50, 100, 200]
missions(1).life_yr    = 5;               % guardian bounding case; inspector reference: 2 yr
missions(1).rtg_note   = 'Significant — GEO eclipse-independent; no solar-array optical glint or pointing constraints. TWO SUB-CONCEPTS within this profile: (A) PERSISTENT free-flyer watchdog/guardian — pays N-S SK floor ~50 m/s/yr + patrol over multi-yr life (Warlock-class; RTG for covert eclipse-independent persistence); (B) DOCKED-SORTIE inspector — rides host (GEO asset or ISAM servicer), detaches for episodic sorties (degraded-asset / ISAM-ops inspection) then redocks; low total dV, burst-recharge cadence ideal, RTG for sortie autonomy. Inspector = time-limited Concept A.';
missions(1).heritage   = 'SSTL SNAP-1 (2000); Infinite Orbits Orbit Guard; Astroscale ELSA-M; US Space Force RPO doctrine; Karpov et al. 2022';

missions(2).label      = 'VLEO drag compensation (~250-350 km)';
missions(2).theme      = 'Earth Orbit';
missions(2).m_sc_kg    = [25, 100, 200];   % lo: small CubeSat; nom: 100 kg class; hi: larger platform
missions(2).dV_ms      = [50, 100, 200];   % annual drag budget: lo gentle aero-opt; nom 100 kg at 300-350 km; hi larger/longer
missions(2).life_yr    = 1;                % reference annual drag compensation budget (dV/yr = dV_nom)
missions(2).rtg_note   = 'Significant — solar viable at LEO; RTG eliminates 7-10 kg battery mass from 16 thermal cycles/day; continuous output well-matched to drag trim profile';
missions(2).heritage   = 'Floberghagen et al. (2011) J. Geodesy (GOCE drag char.); NRLMSISE-00 / JB2008 atm. models; Crisp et al. (2020) Prog. Aerosp. Sci. (ESA DISCOVERER VLEO trade study)';

missions(3).label      = 'Apophis 2029 proximity / companion';
missions(3).theme      = 'Planetary Defence';
missions(3).m_sc_kg    = [15, 25, 50];     % small companion/deployed sub-craft
missions(3).dV_ms      = [5, 15, 30];      % prox-ops only: hover SK + repositioning + Sun-phase hold over ~4-month encounter campaign (NOT the 1530 m/s rendezvous transfer, which is Warlock-class and infeasible for Rogue)
missions(3).life_yr    = 0.5;              % active proximity campaign window (PRE ~40d + CEP + post)
missions(3).rtg_note   = 'Significant — sortie autonomy (full power on deploy/detach); no solar-array glint contaminating optical/spectral obs of pristine surface; inert propellant near sampling target. READINESS GAP: needs Rogue-public I_bit + RTG+; NOT closeable on confirmed 2026 demo HW by a 2028 launch.';
missions(3).heritage   = 'RAMSES (ESA/JAXA 2028-29; rendezvous 1530 m/s -> out of Rogue scope) prox ConOps: 1-20 km hover boxes, 15 km Sun-phase imaging; Hayabusa2/OSIRIS-REx prox heritage; Apophis CA 13 Apr 2029 @ ~31,600 km';

missions(4).label      = 'Asteroid proximity ops (main-belt / cold NEO)';
missions(4).theme      = 'Science (deep)';
missions(4).m_sc_kg    = [15, 25, 50];
missions(4).dV_ms      = [5, 15, 50];     % 5 m/s/yr lo (warm NEO); 15 nom (main belt 3 AU); 50 hi (irregular)
missions(4).life_yr    = 3;
missions(4).rtg_note   = 'Significant to Essential — solar marginal >3 AU; inert propellant safe near pristine target';
missions(4).heritage   = 'Hayabusa2 / OSIRIS-REx heritage; Scheeres et al. 2022 (Apophis); Longhurst (UoM)';

missions(5).label      = 'Icy moon / ocean world orbiter';
missions(5).theme      = 'Science (deep/outer)';
missions(5).m_sc_kg    = [50, 150, 300];    % lo: small; nom: Europa 100 km class; hi: flagship
missions(5).dV_ms      = [50, 100, 200];    % lo: gentle frozen orbit; nom: Europa/Ganymede SK; hi: aggressive
missions(5).life_yr    = 5;
missions(5).rtg_note   = 'Essential for POWER — 4% solar flux at Jupiter (5.2 AU); eclipses up to ~3.5 hr; radiation belt degrades cells -> solar precluded. BUT necessary-not-sufficient: RTG solves power, NOT radiation DOSE. The dose problem (lethal in hours at Europa; ~MRad-class TID) drove the industry FROM orbiters TO flyby (Europa Clipper orbits Jupiter, 49 Europa flybys, electronics vault). An orbiter still demands heavy electronics shielding mass that the propulsion/power trade must carry. Frozen Europa orbits are unstable (~200-day life; Lara/Paskowitz-Scheeres) -> active SK genuinely required.';
missions(5).heritage   = 'Lara (2005) Celest. Mech.; Paskowitz & Scheeres (2006) J. Guidance; Lorenz et al. (2008) Planet. Space Sci.; ESA JUICE (Grasset et al. 2013); Europa Clipper (flyby architecture, radiation vault); cancelled JEO/JIMO orbiter concepts';

n_dd = numel(missions);

%% ── B) BACK-SOLVE ENGINE ─────────────────────────────────────────────────
% For each mission at its nominal m_sc and dV:
%   (1) Total impulse required: Tsiolkovsky (exact; approximation noted).
%   (2) Pulse budget required:  N_req = I_req / I_bit at each I_bit.
%   (3) I_bit threshold:        min I_bit such that Rogue public (3 kNs)
%       covers I_req (i.e. I_bit >= I_req / N_pub).
%   (4) Specific-mass threshold: alpha_max s.t. system fits in f_prop x m_sc.
%   (5) Duty-ceiling check:     does RTG / RTG+ duty provide dV/yr needed?
%   (6) Sensitivity range:      I_req at lo/hi m_sc and dV.

spy = 365.25 * 86400;   % seconds per year

% Power-source net power for duty ceiling (from NEP struct, baseline RTG).
P_net_W      = NEP.rc_max.P_net_W;         % design RTG, ~9.2 W
P_net_plus_W = NEP.rc_max_plus.P_net_W;    % RTG+, ~36.8 W

% Total-impulse specs for Magdrive configs (used as thresholds). Pulled
% from the variant structs when available so a single edit propagates.
if exist('NEP_RP','var'), I_pub_Ns = NEP_RP.I_total_Ns; else, I_pub_Ns = 3000;  end
if exist('NEP_W','var'),  I_warlock_Ns  = NEP_W.I_total_Ns;  else, I_warlock_Ns  = 50000; end
if exist('NEP_SM','var'), I_supermag_Ns = NEP_SM.I_total_Ns; else, I_supermag_Ns = 1e6;   end

% I_bit values to sweep for N_req back-solve (from Params sweep).
I_bit_vec_Ns = cfg.I_bit_sweep_Ns;

for i = 1:n_dd
    m_nom  = missions(i).m_sc_kg(2);
    dV_nom = missions(i).dV_ms(2);
    m_lo   = missions(i).m_sc_kg(1);
    m_hi   = missions(i).m_sc_kg(3);
    dV_lo  = missions(i).dV_ms(1);
    dV_hi  = missions(i).dV_ms(3);

    % System mass (thruster + RTG, worst-case single Rogue + baseline RTG).
    m_sys_kg = rtg.mass_kg + rogue.mass_kg;   % 12.5 + 3.05 = 15.55 kg

    % ── (1) Total impulse required ────────────────────────────────────────
    % Exact Tsiolkovsky: I_total = Isp * g0 * m_prop
    %   where m_prop = m_sc * (1 - exp(-dV / (Isp * g0)))
    % For dV << Isp*g0 (~17640 m/s at 1800s), I_total ≈ m_sc * dV.
    I_req_nom = tsiol_impulse(rogue.Isp_s, g0, m_nom, dV_nom);
    I_req_lo  = tsiol_impulse(rogue.Isp_s, g0, m_lo,  dV_lo);
    I_req_hi  = tsiol_impulse(rogue.Isp_s, g0, m_hi,  dV_hi);

    % ── (2) Pulse budget required at each I_bit ───────────────────────────
    N_req_at_Ibit = I_req_nom ./ I_bit_vec_Ns;   % row of N values

    % ── (3) I_bit threshold to close on Rogue public (3 kNs) ─────────────
    % Spec-equivalent pulse count: 3000 Ns / 100 uN.s = 30M (toolkit
    % convention; equals NEP_RP.cfg.n_pulses_at_spec).
    if exist('NEP_RP','var'), N_pub_pulses = NEP_RP.cfg.n_pulses_at_spec;
    else,                     N_pub_pulses = 30e6; end
    I_bit_threshold_Ns = I_req_nom / N_pub_pulses;   % min I_bit needed

    % ── (4) Specific-mass threshold ───────────────────────────────────────
    % Max allowed system specific mass: m_sys <= f_prop * m_sc
    % => alpha_max = f_prop * m_sc / P_RTG_design
    alpha_max_RTG = cfg.prop_mass_fraction_ref * m_nom / rtg.P_design_W;

    % ── (5) Duty-ceiling check ────────────────────────────────────────────
    % Required annual dV to complete mission in life_yr years.
    dV_per_yr_req = dV_nom / missions(i).life_yr;
    % Available annual dV from duty ceiling (F = I_bit * f; duty-limited).
    dV_duty_RTG  = rogue.F_baseline_N * NEP.rc_max.duty_cycle * spy / m_nom;
    dV_duty_RTGp = rogue.F_baseline_N * NEP.rc_max_plus.duty_cycle * spy / m_nom;
    duty_ok_RTG  = dV_duty_RTG  >= dV_per_yr_req;
    duty_ok_RTGp = dV_duty_RTGp >= dV_per_yr_req;
    % Duty ceiling at the public I_bit: F scales linearly with I_bit
    % (F = I_bit * f), so the ceiling extends ~8.3x over baseline.
    F_pub_N      = 100e-6 * rogue.f_Hz;   % Rogue public thrust at 100 Hz
    dV_duty_pub  = F_pub_N * NEP.rc_max.duty_cycle * spy / m_nom;
    duty_ok_pub  = dV_duty_pub >= dV_per_yr_req;

    % ── (6) Which Magdrive config first closes the mission? ───────────────
    closes_demo   = I_req_nom <= (rogue.I_bit_Ns * rogue.n_pulses_ambition);
    closes_pub    = I_req_nom <= I_pub_Ns;
    closes_warlock= I_req_nom <= I_warlock_Ns;
    closes_supermag= I_req_nom<= I_supermag_Ns;
    if closes_demo
        first_close = sprintf('Rogue demo (%.0f uN.s x 10M)', rogue.I_bit_Ns*1e6);
    elseif closes_pub
        first_close = 'Rogue public (100 uN.s x 30M ~ 3 kNs)';
    elseif closes_warlock
        first_close = 'Warlock (50 kNs)';
    elseif closes_supermag
        first_close = 'SuperMagdrive (1 MNs)';
    else
        first_close = '>SuperMagdrive or infeasible';
    end

    % ── Store results ─────────────────────────────────────────────────────
    dd(i).label              = missions(i).label;
    dd(i).theme              = missions(i).theme;
    dd(i).m_sc_nom_kg        = m_nom;
    dd(i).dV_nom_ms          = dV_nom;
    dd(i).life_yr            = missions(i).life_yr;
    dd(i).I_req_nom_Ns       = I_req_nom;
    dd(i).I_req_range_Ns     = [I_req_lo, I_req_hi];
    dd(i).N_req_at_Ibit      = N_req_at_Ibit;   % length = numel(I_bit_vec)
    dd(i).I_bit_threshold_Ns = I_bit_threshold_Ns;
    dd(i).N_pub_pulses       = N_pub_pulses;
    dd(i).alpha_max_RTG      = alpha_max_RTG;
    dd(i).dV_per_yr_req      = dV_per_yr_req;
    dd(i).dV_duty_RTG        = dV_duty_RTG;
    dd(i).dV_duty_RTGp       = dV_duty_RTGp;
    dd(i).dV_duty_pub        = dV_duty_pub;
    dd(i).duty_ok_RTG        = duty_ok_RTG;
    dd(i).duty_ok_RTGp       = duty_ok_RTGp;
    dd(i).duty_ok_pub        = duty_ok_pub;
    dd(i).closes_demo        = closes_demo;
    dd(i).closes_pub         = closes_pub;
    dd(i).closes_warlock     = closes_warlock;
    dd(i).first_close        = first_close;
    dd(i).heritage           = missions(i).heritage;
    dd(i).rtg_note           = missions(i).rtg_note;
end

%% ── C) REQUIREMENTS MAP POINTS ───────────────────────────────────────────
% Development roadmap coordinates: minimum (I_bit, N_pulses) to close each
% mission at nominal m_sc / dV.
%   I_bit_threshold_Ns:  minimum I_bit s.t. 30M-pulse budget closes the mission
%   N_req_at_100uNs:     pulse budget at 100 uN.s public I_bit

fprintf('\n=========================================================\n');
fprintf('MicroNEP Deep-Dive Back-Solve  —  %d missions\n', n_dd);
fprintf('=========================================================\n\n');

%% ── D) CONSOLE OUTPUT ────────────────────────────────────────────────────
% Table 1: Mission summary
fprintf('Table 1 — Mission overview\n\n');
fprintf('  %-42s | %-22s | %7s | %8s | %7s\n', ...
    'Mission (theme)', 'Theme', 'm_nom', 'dV_nom', 'Life');
fprintf('  %-48s | %-22s | %7s | %8s | %7s\n', ...
    repmat('-',1,48), repmat('-',1,22), '[kg]', '[m/s]', '[yr]');
for i = 1:n_dd
    fprintf('  %-48s | %-22s | %7.0f | %8.0f | %7.0f\n', ...
        dd(i).label, dd(i).theme, dd(i).m_sc_nom_kg, dd(i).dV_nom_ms, dd(i).life_yr);
end

% Table 2: Impulse and pulse-budget requirements
fprintf('\n\nTable 2 — Impulse & pulse-budget requirements  (nom m_sc / dV)\n\n');
fprintf('  %-48s | %8s | %22s | %10s | %10s | %10s\n', ...
    'Mission', 'I_req', 'I_req range', 'N@12uNs', 'N@100uNs', 'I_bit thr.');
fprintf('  %-48s | %8s | %22s | %10s | %10s | %10s\n', ...
    repmat('-',1,48), '[Ns]', '[Ns lo-hi]', '[M pulses]', '[M pulses]', '[uN.s]');
for i = 1:n_dd
    N_12  = dd(i).I_req_nom_Ns / (12e-6)  / 1e6;   % millions at demo I_bit
    N_100 = dd(i).I_req_nom_Ns / (100e-6) / 1e6;   % millions at public I_bit
    fprintf('  %-48s | %8.0f | %5.0f - %5.0f | %10.1f | %10.2f | %10.1f\n', ...
        dd(i).label, dd(i).I_req_nom_Ns, ...
        dd(i).I_req_range_Ns(1), dd(i).I_req_range_Ns(2), ...
        N_12, N_100, dd(i).I_bit_threshold_Ns * 1e6);
end
fprintf('\n  N@12uNs = pulses needed at demo I_bit (12 uN.s)\n');
fprintf('  N@100uNs = pulses needed at public I_bit (100 uN.s)\n');
fprintf('  I_bit thr. = min I_bit [uN.s] s.t. Rogue public (30M pulses) closes mission\n');

% Table 3: Specific mass and duty ceiling
fprintf('\n\nTable 3 — Specific-mass threshold and duty-ceiling check\n\n');
fprintf('  %-48s | %8s | %8s | %8s | %9s | %8s | %8s\n', ...
    'Mission', 'a_max', 'dV/yr req', 'dV RTG', 'dV RTG+', 'dV pub', 'Duty OK?');
fprintf('  %-48s | %8s | %8s | %8s | %9s | %8s | %8s\n', ...
    repmat('-',1,48), '[kg/We]', '[m/s/yr]', '[m/s/yr]', '[m/s/yr]', '[m/s/yr]', 'RTG/RTG+');
for i = 1:n_dd
    ok_str = sprintf('%s / %s', ynstr(dd(i).duty_ok_RTG), ynstr(dd(i).duty_ok_RTGp));
    fprintf('  %-48s | %8.3f | %8.2f | %8.2f | %9.2f | %8.2f | %8s\n', ...
        dd(i).label, dd(i).alpha_max_RTG, ...
        dd(i).dV_per_yr_req, dd(i).dV_duty_RTG, ...
        dd(i).dV_duty_RTGp,  dd(i).dV_duty_pub, ok_str);
end
fprintf('\n  a_max = max system alpha (kg/We) s.t. m_sys <= %.0f%% of m_sc at design RTG power.\n', ...
    cfg.prop_mass_fraction_ref * 100);
fprintf('  dV pub = annual dV ceiling at Rogue public I_bit (100 uN.s, 100 Hz, RTG duty).\n');

% Table 4: First config to close
fprintf('\n\nTable 4 — First Magdrive/PA config that closes each mission\n\n');
fprintf('  %-48s | %-5s | %-5s | %-7s | %-35s\n', ...
    'Mission', 'Demo', 'Pub', 'Warlock', 'First close');
fprintf('  %-48s | %-5s | %-5s | %-7s | %-35s\n', ...
    repmat('-',1,48), '-----', '-----', '-------', repmat('-',1,35));
for i = 1:n_dd
    fprintf('  %-48s |  %-4s |  %-4s |  %-6s | %-35s\n', ...
        dd(i).label, ...
        ynstr(dd(i).closes_demo), ...
        ynstr(dd(i).closes_pub), ...
        ynstr(dd(i).closes_warlock), ...
        dd(i).first_close);
end

% Table 5: Development envelope summary
fprintf('\n\nTable 5 — Development requirements envelope (Fig 7 target points)\n');
fprintf('  These are the (I_bit, N_pulses) requirements that define each mission\n');
fprintf('  as a point on the requirements map. Sequencing R&D to hit these points\n');
fprintf('  in order is the roadmap structure.\n\n');
fprintf('  %-48s | %10s | %10s | %-25s\n', 'Mission', 'I_bit thr.', 'N @ pub.', 'Pull-to');
fprintf('  %-48s | %10s | %10s | %-25s\n', repmat('-',1,48), '[uN.s]', '[M pulses]', '');
for i = 1:n_dd
    N_100_M = dd(i).I_req_nom_Ns / (100e-6) / 1e6;
    fprintf('  %-48s | %10.1f | %10.2f | %-25s\n', ...
        dd(i).label, dd(i).I_bit_threshold_Ns * 1e6, N_100_M, ...
        dd(i).first_close);
end

fprintf('\nMicroNEP_Deep_Dives complete. dd struct populated (%d missions).\n\n', n_dd);


%% ── E) PLOTS ───────────────────────────────────────────────────────────
% Plot A — N_req vs I_bit (continuous requirements curves per DD).
% Plot B — Requirements map: I_bit threshold vs I_total required.

clrs_dd = lines(n_dd);
I_bit_ax = logspace(log10(1e-6), log10(1e-3), 300);

figure('Name','Deep Dives - pulse vs impulse bit'); hold on; grid on;
for i = 1:n_dd
    plot(I_bit_ax*1e6, dd(i).I_req_nom_Ns ./ I_bit_ax / 1e6, ...
        'LineWidth', 1.5, 'Color', clrs_dd(i,:), ...
        'DisplayName', sprintf('DD%d %s  (%.0f Ns)', i, dd(i).theme, dd(i).I_req_nom_Ns));
end
xline(rogue.I_bit_Ns*1e6,'--','Color',[.5 .5 .5],'Label','Rogue demo', ...
    'FontSize',11,'LabelHorizontalAlignment','left','HandleVisibility','off');
xline(100,'--','Color',[.2 .6 .9],'Label','Rogue pub.', ...
    'FontSize',11,'HandleVisibility','off');
xline(500,'--','Color',[.9 .5 .1],'Label','Warlock', ...
    'FontSize',11,'HandleVisibility','off');
yline(10,':','Color',[.4 .4 .4],'Label','10M', ...
    'FontSize',11,'HandleVisibility','off');
yline(30,':','Color',[.1 .1 .1],'Label','30M', ...
    'FontSize',11,'HandleVisibility','off');
set(gca,'XScale','log','YScale','log','FontSize',11);
xlabel('I_{bit} [\muN\cdots]'); ylabel('N_{req} [M pulses]');
title(['DD requirements — pulse budget vs impulse bit  (baseline ' sprintf('%.0f', rogue.I_bit_Ns*1e6) ' \muN\cdots)']);
legend('Location','northeast','FontSize',11);
xlim([1e0 1e3]); ylim([1e-1 1e4]);

I_configs  = [rogue.I_bit_Ns*rogue.n_pulses_ambition, 3000, 50000, 1e6];
cfg_lbl_b  = {'Rogue Demo.','Rogue Pub.','Warlock','SuperMag'};
cfg_clrs_b = {[.5 .5 .5],[.2 .6 .9],[.9 .5 .1],[.7 .2 .8]};
figure('Name','Deep Dives - requirements'); hold on; grid on;
for c = 1:4
    yline(I_configs(c),'--','Color',cfg_clrs_b{c},...
        'Label',cfg_lbl_b{c},'FontSize',11,'LabelHorizontalAlignment','right',...
        'HandleVisibility','off');
end
lbl_left = 4;   % DD indices to label on the left instead of the right

for i = 1:n_dd
    scatter(dd(i).I_bit_threshold_Ns*1e6, dd(i).I_req_nom_Ns, 80, clrs_dd(i,:),'filled','p',...
'HandleVisibility','off');
    if ismember(i, lbl_left)
        xf = 1/1.08;  hAlign = 'right';
    else
        xf = 1.08;    hAlign = 'left';
    end
    text(dd(i).I_bit_threshold_Ns*1e6*xf, dd(i).I_req_nom_Ns, ...
        sprintf('DD%d: %s', i, strtok(dd(i).label)), ...
        'FontSize',11,'Color',clrs_dd(i,:),'HorizontalAlignment',hAlign);
end
set(gca,'XScale','log','YScale','log','FontSize',11);
xlabel('I_{bit} threshold [\muN\cdots]'); ylabel('I_{total} required [N\cdots]');
title('Mission requirements map — development targets (I_{bit} threshold vs I_{total})');
xlim([1e0 1e3]); ylim([1e2 1e6]);

%% ── F) LOCAL FUNCTIONS ──────────────────────────────────────────────────

function I = tsiol_impulse(Isp, g0, m_sc, dV)
% Exact Tsiolkovsky total impulse [Ns] for a given dV and spacecraft mass.
% I_total = Isp * g0 * m_prop, where m_prop = m_sc*(1 - exp(-dV/(Isp*g0))).
% For dV << Isp*g0, I_total ≈ m_sc * dV (< 0.3% error at 100 m/s / 1800 s).
    m_prop = m_sc * (1 - exp(-dV / (Isp * g0)));
    I = Isp * g0 * m_prop;
end

function s = ynstr(tf)
    if tf, s = 'YES'; else, s = 'no'; end
end