%% =========================================================================
%% MicroNEP_Rogue_Public.m — Rogue 3 Public-Spec Analysis
%% =========================================================================
% Performance assessment using the Magdrive Rogue 3 public headline
% specifications (10 mN, 3 kNs, 1800-3500 s Isp). Thruster hardware is
% identical to MicroNEP_Model.m; only I_bit and total impulse differ.
% Two power options are assessed: PA Am-241 RTG (baseline) and RTG+.
%
% All analysis sections (operating point, m_sc x N grid, eta_charge sweep,
% mass band, stacking, packaging) are implemented once in
% MicroNEP_Variant_Core.m; this script only defines the variant inputs.
%
% I_bit derivations:
%   F_max / f_max     -> 100 uN.s   (primary, conservative)
%   I_total / 10M     -> 300 uN.s   (optimistic, full pulse-budget)
% Toolkit convention: screened at the 3 kNs public spec, which at the
% conservative 100 uN.s implies a 30M-pulse life (n_pulses_at_spec).
%
% Outputs the standardised NEP_RP struct consumed by
% MicroNEP_Family_Compare.m, MicroNEP_Plots.m, and MicroNEP_Summary.m.
%
% Run order: MicroNEP_Params.m -> MicroNEP_Model.m -> this script.

if ~exist('rogue','var'), error('Run MicroNEP_Params.m first.'); end
if ~exist('NEP','var'),   error('Run MicroNEP_Model.m first.');  end

%% ── A) ROGUE PUBLIC PARAMETERS ──────────────────────────────────────────
vc_RP.label         = 'Rogue 3 (public spec)';
vc_RP.banner        = 'ROGUE 3 PUBLIC SPEC';
vc_RP.F_max_mN      = 10.0;
vc_RP.I_total_Ns    = 3000;
vc_RP.Isp_s         = rogue.Isp_s;
vc_RP.E_store_J     = rogue.E_store_J;
vc_RP.E_pulse_J     = rogue.E_per_pulse_J;
vc_RP.f_max_Hz      = rogue.f_Hz;
vc_RP.m_thruster_kg = rogue.mass_kg;
vc_RP.m_prop_kg     = rogue.m_prop_kg;
vc_RP.P_charge_W    = NaN;
vc_RP.PPU_eta       = rogue.eta_chain;

vc_RP.data_status.I_bit      = 'derived (F_max / f_max)';
vc_RP.data_status.I_total    = 'public';
vc_RP.data_status.Isp        = 'public';
vc_RP.data_status.PPU_eta    = 'derived (Rogue confirmed chain)';
vc_RP.data_status.power_mass = 'RTG confirmed | RTG+ direction confirmed';

% Confirmed engineering hardware -> tight +/-10% band on head mass.
vc_RP.unc_frac      = 0.10;
vc_RP.m_sc_ref_kg   = cfg.m_ref_kg;
% Rogue-class platforms span 10 kg cubesat to 200 kg smallsat.
vc_RP.grid_m_sc_kg  = [10, 25, 50, 100, 200];
vc_RP.default_idx   = 1;                       % RTG baseline
vc_RP.opt_keys      = {'rtg', 'rtg_plus'};
vc_RP.opt_short     = {'RTG', 'RTG+'};
vc_RP.rchg_in_hours = false;

%% ── B) POWER SYSTEM OPTIONS ─────────────────────────────────────────────
pwr_RP(1).type       = 'RTG';
pwr_RP(1).label      = 'PA Am-241 RTG';
pwr_RP(1).P_e_W      = rtg.P_design_W;
pwr_RP(1).m_kg       = rtg.mass_kg;
pwr_RP(1).alpha_kgWe = rtg.specific_mass_kgWe;
pwr_RP(1).eta        = NaN;
pwr_RP(1).confirmed  = true;

pwr_RP(2).type       = 'RTG';
pwr_RP(2).label      = 'PA Am-241 RTG+ (improved TEG)';
pwr_RP(2).P_e_W      = rtg_plus.P_design_W;
pwr_RP(2).m_kg       = rtg_plus.mass_kg;
pwr_RP(2).alpha_kgWe = rtg_plus.specific_mass_kgWe;
pwr_RP(2).eta        = NaN;
pwr_RP(2).confirmed  = false;

%% ── C-G) RUN SHARED CORE ────────────────────────────────────────────────
base_RP = struct('rogue',rogue, 'rtg',rtg, 'mppt',mppt, 'g0',g0, ...
                 'n_stk_max',cfg.n_stk_max);
NEP_RP  = MicroNEP_Variant_Core(vc_RP, pwr_RP, base_RP);
