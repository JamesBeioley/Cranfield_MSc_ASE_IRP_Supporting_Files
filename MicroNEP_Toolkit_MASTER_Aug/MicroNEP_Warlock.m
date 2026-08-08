%% =========================================================================
%% MicroNEP_Warlock.m — Warlock + Power System Analysis
%% =========================================================================
% Performance assessment for the Magdrive Warlock public spec (50 mN, 50 kNs,
% 2500 s Isp, 50 kJ store) paired with four power options: PA Am-241 RTG
% trickle charge, RSG-35, RSG-100, and RTG+ (default). Outputs the
% standardised NEP_W struct consumed by Family_Compare / Plots / Summary.
%
% All analysis sections are implemented once in MicroNEP_Variant_Core.m;
% this script only defines the variant inputs.
%
% I_bit derivations:
%   F_max / f_max     ->   500 uN.s   (primary, conservative)
%   I_total / 10M     ->  5000 uN.s   (optimistic, full pulse-budget)
% Toolkit convention: screened at the 50 kNs public spec, which at the
% conservative 500 uN.s implies a 100M-pulse life (n_pulses_at_spec).
%
% RSG mass figures are estimated from Mesalam et al. 2024 and
% Lewandowski & Oriti 2016.
%
% Run order: MicroNEP_Params.m -> MicroNEP_Model.m -> this script.

if ~exist('rogue','var'), error('Run MicroNEP_Params.m first.'); end
if ~exist('NEP','var'),   error('Run MicroNEP_Model.m first.');  end

%% ── A) WARLOCK PARAMETERS ───────────────────────────────────────────────
vc_W.label         = 'Warlock (public spec)';
vc_W.banner        = 'WARLOCK';
vc_W.F_max_mN      = 50.0;
vc_W.I_total_Ns    = 50000;                 % 50 kNs
vc_W.Isp_s         = 2500;
vc_W.E_store_J     = 50000;                 % 50 kJ, 5x Rogue
vc_W.E_pulse_J     = rogue.E_per_pulse_J;   % assumed common
vc_W.f_max_Hz      = rogue.f_Hz;            % assumed common
vc_W.m_thruster_kg = 3.0;
vc_W.m_prop_kg     = NaN;
vc_W.P_charge_W    = 150;                   % rated charge power
vc_W.PPU_eta       = NaN;

vc_W.data_status.I_bit      = 'derived (F_max / f_max)';
vc_W.data_status.I_total    = 'public';
vc_W.data_status.Isp        = 'public';
vc_W.data_status.PPU_eta    = 'pending; assumed Rogue chain';
vc_W.data_status.power_mass = 'RTG confirmed | RSG estimated (Mesalam 2024)';

% Warlock thruster head mass is a single public point estimate -> +/-30%.
vc_W.unc_frac      = 0.30;
vc_W.m_sc_ref_kg   = 100;                   % Warlock-class platform reference
vc_W.grid_m_sc_kg  = [50, 100, 200, 500, 1000];
vc_W.default_idx   = 4;                     % RTG+ (best single-unit option)
vc_W.opt_keys      = {'rtg', 'rsg35', 'rsg100', 'rtg_plus'};
vc_W.opt_short     = {'RTG', 'RSG-35', 'RSG-100', 'RTG+'};
vc_W.rchg_in_hours = false;

%% ── B) POWER SYSTEM OPTIONS ─────────────────────────────────────────────
% Order is fixed: Plots and Summary index unc/ops arrays positionally.
pwr_W(1).type       = 'RTG';
pwr_W(1).label      = 'PA Am-241 RTG';
pwr_W(1).P_e_W      = rtg.P_design_W;
pwr_W(1).m_kg       = rtg.mass_kg;
pwr_W(1).alpha_kgWe = rtg.specific_mass_kgWe;
pwr_W(1).eta        = NaN;
pwr_W(1).confirmed  = true;

pwr_W(2).type       = 'RSG';
pwr_W(2).label      = 'PA RSG-35 (Stirling, estimated)';
pwr_W(2).P_e_W      = rsg(1).P_design_W;
pwr_W(2).m_kg       = rsg(1).mass_kg;       % Mesalam 2024 Fig 2 (~1 ELHS module)
pwr_W(2).alpha_kgWe = rsg(1).specific_mass_kgWe;
pwr_W(2).eta        = 0.22;
pwr_W(2).confirmed  = false;

pwr_W(3).type       = 'RSG';
pwr_W(3).label      = 'PA RSG-100 (Stirling, estimated)';
pwr_W(3).P_e_W      = rsg(2).P_design_W;
pwr_W(3).m_kg       = rsg(2).mass_kg;       % Mesalam 2024 Fig 2 (~2 ELHS modules)
pwr_W(3).alpha_kgWe = rsg(2).specific_mass_kgWe;
pwr_W(3).eta        = 0.22;
pwr_W(3).confirmed  = false;

pwr_W(4).type       = 'RTG';
pwr_W(4).label      = 'PA Am-241 RTG+ (improved TEG)';
pwr_W(4).P_e_W      = rtg_plus.P_design_W;
pwr_W(4).m_kg       = rtg_plus.mass_kg;
pwr_W(4).alpha_kgWe = rtg_plus.specific_mass_kgWe;
pwr_W(4).eta        = NaN;
pwr_W(4).confirmed  = false;

%% ── C-G) RUN SHARED CORE ────────────────────────────────────────────────
base_W = struct('rogue',rogue, 'rtg',rtg, 'mppt',mppt, 'g0',g0, ...
                'n_stk_max',cfg.n_stk_max);
NEP_W  = MicroNEP_Variant_Core(vc_W, pwr_W, base_W);
