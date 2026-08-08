%% =========================================================================
%% MicroNEP_SuperMag.m — SuperMagdrive + Power System Analysis
%% =========================================================================
% Conceptual flagship analysis at the SuperMagdrive scale (1 N, 1 MNs,
% 2000 s Isp, 2 MJ store) paired with five power options: PA Am-241 RTG,
% RTG+, RSG-35, RSG-100, and RSG-200 (default). RTG and RTG+ are included
% for context; RSG-200 is the minimum viable option at this thruster scale.
% Outputs the standardised NEP_SM struct consumed by Family_Compare /
% Plots / Summary.
%
% All analysis sections are implemented once in MicroNEP_Variant_Core.m;
% this script only defines the variant inputs.
%
% I_bit derivations:
%   F_max / f_max      ->  10000 uN.s   (primary, conservative)
%   I_total / 10M      -> 100000 uN.s   (optimistic, full pulse-budget)
%   Early test report  ->    100 uN.s   (unconfirmed, well below F_max/f)
% Toolkit convention: screened at the 1 MNs public-indicative spec, which
% at the conservative 10000 uN.s implies a 100M-pulse life.
%
% RSG mass figures are estimated from Mesalam et al. 2024 and
% Lewandowski & Oriti 2016. All SuperMagdrive thruster values are
% extrapolations from public material; no ICD data exists.
%
% Run order: MicroNEP_Params.m -> MicroNEP_Model.m -> this script.

if ~exist('rogue','var'), error('Run MicroNEP_Params.m first.'); end
if ~exist('NEP','var'),   error('Run MicroNEP_Model.m first.');  end

%% ── A) SUPERMAGDRIVE PARAMETERS ─────────────────────────────────────────
vc_SM.label         = 'SuperMagdrive (conceptual)';
vc_SM.banner        = 'SUPERMAGDRIVE';
vc_SM.F_max_mN      = 1000.0;               % 1 N public indicative
vc_SM.I_total_Ns    = 1e6;                  % 1 MNs public indicative
vc_SM.Isp_s         = 2000;
vc_SM.E_store_J     = 2e6;                  % 2 MJ public indicative
vc_SM.E_pulse_J     = rogue.E_per_pulse_J;  % assumed common
vc_SM.f_max_Hz      = rogue.f_Hz;           % assumed common
vc_SM.m_thruster_kg = 75;
vc_SM.m_prop_kg     = NaN;
vc_SM.P_charge_W    = NaN;
vc_SM.PPU_eta       = NaN;
vc_SM.I_bit_early_Ns = 100e-6;              % unconfirmed early-test report
vc_SM.extra_lines   = {sprintf('Early test report             : %.0f uN.s  [unconfirmed]', 100e-6*1e6)};

vc_SM.data_status.I_bit      = 'derived (F_max / f_max); early test ~100 uN.s';
vc_SM.data_status.I_total    = 'public indicative';
vc_SM.data_status.Isp        = 'public indicative';
vc_SM.data_status.PPU_eta    = 'pending';
vc_SM.data_status.power_mass = 'RTG below threshold; RSG-200 estimated (Mesalam 2024)';

% Conceptual extrapolation -> +/-40% head-mass band.
vc_SM.unc_frac      = 0.40;
vc_SM.m_sc_ref_kg   = 500;                  % SuperMagdrive-class platform reference
% SuperMagdrive-class platforms span 200 kg cubesat-mother to 5 t flagship.
vc_SM.grid_m_sc_kg  = [200, 500, 1000, 2000, 5000];
vc_SM.default_idx   = 5;                    % RSG-200
vc_SM.opt_keys      = {'rtg', 'rtg_plus', 'rsg35', 'rsg100', 'rsg200'};
vc_SM.opt_short     = {'RTG', 'RTG+', 'RSG-35', 'RSG-100', 'RSG-200'};
vc_SM.rchg_in_hours = true;

%% ── B) POWER SYSTEM OPTIONS ─────────────────────────────────────────────
% Order is fixed: Plots and Summary index unc/ops arrays positionally.
pwr_SM(1).type       = 'RTG';
pwr_SM(1).label      = 'PA Am-241 RTG';
pwr_SM(1).P_e_W      = rtg.P_design_W;
pwr_SM(1).m_kg       = rtg.mass_kg;
pwr_SM(1).alpha_kgWe = rtg.specific_mass_kgWe;
pwr_SM(1).eta        = NaN;
pwr_SM(1).confirmed  = true;

pwr_SM(2).type       = 'RTG';
pwr_SM(2).label      = 'PA Am-241 RTG+ (improved TEG)';
pwr_SM(2).P_e_W      = rtg_plus.P_design_W;
pwr_SM(2).m_kg       = rtg_plus.mass_kg;
pwr_SM(2).alpha_kgWe = rtg_plus.specific_mass_kgWe;
pwr_SM(2).eta        = NaN;
pwr_SM(2).confirmed  = false;

pwr_SM(3).type       = 'RSG';
pwr_SM(3).label      = 'PA RSG-35 (Stirling, estimated)';
pwr_SM(3).P_e_W      = rsg(1).P_design_W;
pwr_SM(3).m_kg       = rsg(1).mass_kg;
pwr_SM(3).alpha_kgWe = rsg(1).specific_mass_kgWe;
pwr_SM(3).eta        = 0.22;
pwr_SM(3).confirmed  = false;

pwr_SM(4).type       = 'RSG';
pwr_SM(4).label      = 'PA RSG-100 (Stirling, estimated)';
pwr_SM(4).P_e_W      = rsg(2).P_design_W;
pwr_SM(4).m_kg       = rsg(2).mass_kg;
pwr_SM(4).alpha_kgWe = rsg(2).specific_mass_kgWe;
pwr_SM(4).eta        = 0.22;
pwr_SM(4).confirmed  = false;

pwr_SM(5).type       = 'RSG';
pwr_SM(5).label      = 'PA RSG-200 (Stirling, estimated)';
pwr_SM(5).P_e_W      = rsg(3).P_design_W;
pwr_SM(5).m_kg       = rsg(3).mass_kg;      % Mesalam 2024 Table 7/8: 110 kg confirmed design point
pwr_SM(5).alpha_kgWe = rsg(3).specific_mass_kgWe;
pwr_SM(5).eta        = 0.22;
pwr_SM(5).confirmed  = false;

%% ── C-G) RUN SHARED CORE ────────────────────────────────────────────────
base_SM = struct('rogue',rogue, 'rtg',rtg, 'mppt',mppt, 'g0',g0, ...
                 'n_stk_max',cfg.n_stk_max);
NEP_SM  = MicroNEP_Variant_Core(vc_SM, pwr_SM, base_SM);
