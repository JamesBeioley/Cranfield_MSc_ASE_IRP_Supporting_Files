function NEP_X = MicroNEP_Variant_Core(vc, pwr, base)
%% =========================================================================
%% MicroNEP_Variant_Core.m — Shared Magdrive-Variant Analysis Engine
%% =========================================================================
% Single parameterised implementation of the variant analysis previously
% duplicated across MicroNEP_Rogue_Public / _Warlock / _SuperMag. Guarantees
% the NEP_RP / NEP_W / NEP_SM schemas cannot drift apart.
%
% Sections (mirrors the original variant-script lettering):
%   A) Derived thruster parameters (I_bit derivations, burst, T/P)
%   C) Operating point per power option
%   D) Operating-point grid (m_sc x N_pulses) with feasibility flags
%   E) PPU charge-side efficiency sweep (eta moves duty/recharge only;
%      lifetime dV is impulse-limited and invariant, so the sweep records
%      annual pulse throughput instead of a constant dV column)
%   F) Mass uncertainty band (head +/- vc.unc_frac)
%   F.5) Stacking grid (n_R x n_T) at the default power option
%   G) Package into NEP_X struct and print trimmed load message
%
% INPUTS
%   vc   variant config:
%          .label, .banner          display strings
%          .F_max_mN, .I_total_Ns, .Isp_s            public/derived spec
%          .E_store_J, .E_pulse_J, .f_max_Hz         pulse architecture
%          .m_thruster_kg, .m_prop_kg, .P_charge_W, .PPU_eta
%          .data_status              struct of provenance strings
%          .unc_frac                 head-mass uncertainty fraction
%          .m_sc_ref_kg              reference spacecraft mass
%          .grid_m_sc_kg             masses for the m_sc x N grid
%          .default_idx              index into pwr of the default option
%          .opt_keys / .opt_short    field suffixes / table labels per option
%          .rchg_in_hours            true -> ops table prints recharge in hr
%          .extra_lines              optional cellstr appended after I_bit
%                                    derivations in the load message
%   pwr  power-option struct array (.type .label .P_e_W .m_kg .alpha_kgWe
%        .eta .confirmed) in the FIXED order consumed by Plots/Summary.
%   base struct with .rogue .rtg .mppt .g0 (from Params/Model workspace).
%
% CONVENTION (toolkit-wide): the variant is screened at its public
% total-impulse spec. The spec-equivalent pulse count is
%   n_pulses_at_spec = I_total_Ns / I_bit_Ns
% and downstream feasibility screens treat delivered impulse as fixed at
% I_total_Ns. The m_sc x N grid (section D) remains a sweep over N and so
% keeps the min(I_bit*N, I_total) cap.
%% =========================================================================

rogue = base.rogue;  rtg = base.rtg;  mppt = base.mppt;  g0 = base.g0;
spy   = 365.25 * 86400;

%% ── A) DERIVED THRUSTER PARAMETERS ──────────────────────────────────────
cfg_X = vc;   % carry all caller fields through into the cfg record

% I_bit derivations:
%   F_max / f_max            -> conservative (primary)
%   I_total / 10M ambition   -> optimistic (full Rogue-class pulse budget)
cfg_X.I_bit_from_F     = vc.F_max_mN * 1e-3 / vc.f_max_Hz;
cfg_X.I_bit_from_IT    = vc.I_total_Ns / rogue.n_pulses_ambition;
cfg_X.I_bit_Ns         = cfg_X.I_bit_from_F;            % conservative
cfg_X.n_pulses_at_spec = vc.I_total_Ns / cfg_X.I_bit_Ns;

cfg_X.t_burst_s    = vc.E_store_J / (vc.E_pulse_J * vc.f_max_Hz);
cfg_X.T_per_P_mNkW = (cfg_X.I_bit_Ns / vc.E_pulse_J) * 1e6;

%% ── C) OPERATING POINT PER POWER OPTION ─────────────────────────────────
n_opt = numel(pwr);
for p = 1:n_opt
    P_net    = pwr(p).P_e_W * mppt.eta - rtg.P_parasitic_W;
    rchg_s   = vc.E_store_J / P_net;
    duty     = cfg_X.t_burst_s / (cfg_X.t_burst_s + rchg_s);
    % Calendar days to deplete the public spec at maximum cadence.
    cal_life_days = (vc.I_total_Ns / cfg_X.I_bit_Ns) * ...
                    (cfg_X.t_burst_s + rchg_s) / vc.f_max_Hz / cfg_X.t_burst_s / 86400;

    ops(p).label         = pwr(p).label;
    ops(p).P_net_W       = P_net;
    ops(p).rchg_s        = rchg_s;
    ops(p).rchg_min      = rchg_s / 60;
    ops(p).rchg_hr       = rchg_s / 3600;
    ops(p).duty_pct      = duty * 100;
    ops(p).t_burst_s     = cfg_X.t_burst_s;
    ops(p).F_mN          = cfg_X.I_bit_Ns * vc.f_max_Hz * 1e3;
    ops(p).cal_life_days = cal_life_days;
    ops(p).m_sc_ref_kg   = vc.m_sc_ref_kg;

    for n_ref = [1e6, 10e6, 50e6]
        % Delivered impulse capped at the public spec (fixed-spec
        % convention) so the ops columns agree with the section-D grid.
        I_del = min(cfg_X.I_bit_Ns * n_ref, vc.I_total_Ns);
        m_p   = I_del / (vc.Isp_s * g0);
        if m_p >= vc.m_sc_ref_kg
            dV = Inf;
        else
            dV = vc.Isp_s * g0 * log(vc.m_sc_ref_kg / (vc.m_sc_ref_kg - m_p));
        end
        ops(p).(sprintf('dV_%dM_ms', round(n_ref/1e6))) = dV;
    end
end

%% ── D) OPERATING-POINT GRID (m_sc x N_pulses) ───────────────────────────
% dV-feasibility surface per power option. Sweep over N, so delivered
% impulse is capped at the public spec: I_del = min(I_bit*N, I_total).
op_grid.m_sc_kg  = vc.grid_m_sc_kg;
op_grid.N_pulses = [1e6, 5e6, 10e6, 50e6, 100e6];
n_m = numel(op_grid.m_sc_kg);
n_N = numel(op_grid.N_pulses);

for p = 1:n_opt
    P_net_p  = pwr(p).P_e_W * mppt.eta - rtg.P_parasitic_W;
    rchg_p   = vc.E_store_J / max(P_net_p, eps);
    duty_p   = cfg_X.t_burst_s / (cfg_X.t_burst_s + rchg_p);
    n_per_yr = vc.f_max_Hz * duty_p * spy;

    dV_grid = nan(n_m, n_N);
    fb_grid = false(n_m, n_N);   % feasible flag (impulse-mass closure)
    cl_grid = nan(n_m, n_N);     % calendar life [years] at duty cap
    for r = 1:n_m
        m_sc  = op_grid.m_sc_kg(r);
        m_sys = vc.m_thruster_kg + pwr(p).m_kg;
        if m_sc <= m_sys, continue; end
        for c = 1:n_N
            I_del = min(cfg_X.I_bit_Ns * op_grid.N_pulses(c), vc.I_total_Ns);
            m_p   = I_del / (vc.Isp_s * g0);
            if m_p < m_sc - m_sys
                dV_grid(r,c) = vc.Isp_s * g0 * log(m_sc / (m_sc - m_p));
                fb_grid(r,c) = true;
            end
            cl_grid(r,c) = op_grid.N_pulses(c) / n_per_yr;
        end
    end
    op_grid.dV_ms{p}       = dV_grid;
    op_grid.feasible{p}    = fb_grid;
    op_grid.cal_life_yr{p} = cl_grid;
    op_grid.label{p}       = pwr(p).label;
end

%% ── E) PPU CHARGE-SIDE EFFICIENCY SWEEP ─────────────────────────────────
% At the default power option. Lifetime dV is impulse-limited and therefore
% invariant in eta_charge; the sweep records what eta actually moves —
% recharge time, duty, and annual pulse throughput. Discharge chain
% (eta_chain) does not enter recharge; recorded as a jet-power assumption.
d_idx = vc.default_idx;
sweep.eta_charge        = [0.85, 0.90, 0.92, 0.95, 0.98];
sweep.eta_chain_assumed = rogue.eta_chain;
sweep.P_e_W             = pwr(d_idx).P_e_W;
sweep.m_sc_kg           = vc.m_sc_ref_kg;
sweep.note              = 'Lifetime dV invariant in eta_charge (impulse-limited).';

n_e = numel(sweep.eta_charge);
sweep.P_net_W          = nan(1, n_e);
sweep.rchg_min         = nan(1, n_e);
sweep.duty_pct         = nan(1, n_e);
sweep.pulses_per_yr_M  = nan(1, n_e);
for k = 1:n_e
    P_net = sweep.P_e_W * sweep.eta_charge(k) - rtg.P_parasitic_W;
    if P_net <= 0, continue; end
    rchg_s = vc.E_store_J / P_net;
    duty   = cfg_X.t_burst_s / (cfg_X.t_burst_s + rchg_s);
    sweep.P_net_W(k)         = P_net;
    sweep.rchg_min(k)        = rchg_s / 60;
    sweep.duty_pct(k)        = duty * 100;
    sweep.pulses_per_yr_M(k) = vc.f_max_Hz * duty * spy / 1e6;
end

%% ── F) MASS UNCERTAINTY BAND ────────────────────────────────────────────
unc.frac         = vc.unc_frac;
unc.m_thr_lo_kg  = vc.m_thruster_kg * (1 - unc.frac);
unc.m_thr_nom_kg = vc.m_thruster_kg;
unc.m_thr_hi_kg  = vc.m_thruster_kg * (1 + unc.frac);
for p = 1:n_opt
    unc.m_sys_lo_kg(p)    = unc.m_thr_lo_kg  + pwr(p).m_kg;
    unc.m_sys_nom_kg(p)   = unc.m_thr_nom_kg + pwr(p).m_kg;
    unc.m_sys_hi_kg(p)    = unc.m_thr_hi_kg  + pwr(p).m_kg;
    unc.alpha_lo_kgWe(p)  = unc.m_sys_lo_kg(p)  / pwr(p).P_e_W;
    unc.alpha_nom_kgWe(p) = unc.m_sys_nom_kg(p) / pwr(p).P_e_W;
    unc.alpha_hi_kgWe(p)  = unc.m_sys_hi_kg(p)  / pwr(p).P_e_W;
end

%% ── F.5) STACKING GRID (n_R x n_T) AT DEFAULT POWER ────────────────────
% Duty depends only on n_T; impulse and thrust scale with n_R.
% Delivered impulse fixed at the public spec per unit (toolkit convention).
n_max      = base.n_stk_max;
P_per_unit = pwr(d_idx).P_e_W;
m_per_unit = pwr(d_idx).m_kg;
for nr = 1:n_max
    for nt = 1:n_max
        P_net   = nt * (P_per_unit * mppt.eta - rtg.P_parasitic_W);
        E_tot   = nr * vc.E_store_J;
        t_rchg  = E_tot / P_net;
        t_burst = E_tot / (vc.E_pulse_J * vc.f_max_Hz);
        stk(nr,nt).n_R        = nr;
        stk(nr,nt).n_T        = nt;
        stk(nr,nt).mass_kg    = nr * vc.m_thruster_kg + nt * m_per_unit;
        stk(nr,nt).P_net_W    = P_net;
        stk(nr,nt).rchg_min   = t_rchg / 60;
        stk(nr,nt).duty_pct   = t_burst / (t_burst + t_rchg) * 100;
        stk(nr,nt).F_mN       = nr * cfg_X.I_bit_Ns * vc.f_max_Hz * 1e3;
        stk(nr,nt).I_total_Ns = nr * vc.I_total_Ns;
        stk(nr,nt).alpha_sys  = stk(nr,nt).mass_kg / (nt * P_per_unit);
    end
end

%% ── G) PACKAGE INTO NEP_X STRUCT ────────────────────────────────────────
NEP_X.label          = vc.label;
NEP_X.I_bit_Ns       = cfg_X.I_bit_Ns;
NEP_X.Isp_s          = vc.Isp_s;
NEP_X.F_max_mN       = vc.F_max_mN;
NEP_X.T_P_mNkW       = cfg_X.T_per_P_mNkW;
NEP_X.I_total_Ns     = vc.I_total_Ns;
NEP_X.E_store_J      = vc.E_store_J;
NEP_X.E_pulse_J      = vc.E_pulse_J;
NEP_X.f_max_Hz       = vc.f_max_Hz;
NEP_X.t_burst_s      = cfg_X.t_burst_s;
NEP_X.m_thruster_kg  = vc.m_thruster_kg;
NEP_X.m_prop_kg      = vc.m_prop_kg;
NEP_X.PPU_eta        = vc.PPU_eta;

NEP_X.power = pwr(d_idx);
NEP_X.ops   = ops(d_idx);
for p = 1:n_opt
    NEP_X.(['power_' vc.opt_keys{p}]) = pwr(p);
    NEP_X.(['ops_'   vc.opt_keys{p}]) = ops(p);
end

NEP_X.mass.thruster_kg = vc.m_thruster_kg;
NEP_X.mass.power_kg    = pwr(d_idx).m_kg;
NEP_X.mass.system_kg   = vc.m_thruster_kg + pwr(d_idx).m_kg;
NEP_X.mass.alpha_sys   = NEP_X.mass.system_kg / pwr(d_idx).P_e_W;

NEP_X.grid        = op_grid;
NEP_X.sweep       = sweep;
NEP_X.unc         = unc;
NEP_X.stk         = stk;
NEP_X.data_status = vc.data_status;
NEP_X.cfg         = cfg_X;

%% ── LOAD MESSAGE (trimmed headline; full tables live in Summary s16) ────
fprintf('\n%s\n  %s\n%s\n', repmat('=',1,72), vc.banner, repmat('=',1,72));

fprintf('\n  I_bit derivations:\n');
fprintf('    F_max / f_max (conservative)  : %.0f uN.s  [primary]\n', cfg_X.I_bit_from_F*1e6);
fprintf('    I_total / 10M (optimistic)    : %.0f uN.s\n', cfg_X.I_bit_from_IT*1e6);
if isfield(vc,'extra_lines')
    for L = 1:numel(vc.extra_lines), fprintf('    %s\n', vc.extra_lines{L}); end
end
fprintf('  Thrust        : %.1f mN at %.0f Hz  | Burst %s  | T/P %.1f mN/kW\n', ...
    ops(1).F_mN, vc.f_max_Hz, fmt_dur(cfg_X.t_burst_s), cfg_X.T_per_P_mNkW);
fprintf('  I_total       : %.0f Ns public spec  (= %.0fM pulses at %.0f uN.s)\n', ...
    vc.I_total_Ns, cfg_X.n_pulses_at_spec/1e6, cfg_X.I_bit_Ns*1e6);

fprintf('\n  Operating point (dV at the 10M-pulse budget, %.0f kg ref s/c):\n', vc.m_sc_ref_kg);
if vc.rchg_in_hours, r_hdr = 'rchg[hr]'; else, r_hdr = 'rchg[min]'; end
fprintf('    %-32s | %8s | %10s | %8s | %9s | %10s\n', ...
    'Power option', 'P_net[W]', r_hdr, 'duty[%]', 'cal[days]', 'dV_10M[m/s]');
fprintf('    %s\n', repmat('-',1,92));
for p = 1:n_opt
    tag = '';
    if p == d_idx, tag = '  [default]'; end
    if vc.rchg_in_hours, r_val = ops(p).rchg_hr; else, r_val = ops(p).rchg_min; end
    fprintf('    %-32s | %8.2f | %10.1f | %8.2f | %9.0f | %10s%s\n', ...
        vc.opt_short{p}, ops(p).P_net_W, r_val, ops(p).duty_pct, ...
        ops(p).cal_life_days, fmt_dv_local(ops(p).dV_10M_ms), tag);
end

fprintf('\n  Feasibility grid (m_sc x N_pulses):\n');
for p = 1:n_opt
    fprintf('    %-10s: %d/%d cells feasible\n', vc.opt_short{p}, ...
        sum(op_grid.feasible{p}(:)), n_m * n_N);
end

fprintf('\n  Stack 5x5    : I_total %.0f - %.0f Ns  | duty %.2f - %.2f%%\n', ...
    stk(1,1).I_total_Ns, stk(n_max,n_max).I_total_Ns, ...
    stk(1,1).duty_pct, stk(1,n_max).duty_pct);
fprintf('  (eta_charge sweep and head-mass band tables: MicroNEP_Summary.m, section 16)\n');
fprintf('\n%s\n\n', repmat('=',1,72));

end

%% ── LOCAL FUNCTIONS ─────────────────────────────────────────────────────
function s = fmt_dv_local(v)
    if isnan(v),     s = 'N/A';
    elseif isinf(v), s = '>prop';
    else,            s = sprintf('%.2f', v);
    end
end

function s = fmt_dur(t_s)
% Burst duration in the most readable unit.
    if t_s < 120,        s = sprintf('%.0f s', t_s);
    elseif t_s < 7200,   s = sprintf('%.0f min', t_s/60);
    else,                s = sprintf('%.1f hr', t_s/3600);
    end
end
