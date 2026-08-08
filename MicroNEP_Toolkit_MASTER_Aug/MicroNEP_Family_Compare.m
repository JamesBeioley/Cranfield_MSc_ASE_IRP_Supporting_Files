%% =========================================================================
%% MicroNEP_Family_Compare.m — Magdrive Family Cross-Comparison
%% =========================================================================
% Cross-comparison of four Magdrive family points (Rogue confirmed, Rogue
% public, Warlock, SuperMagdrive) with their default power systems. Outputs
% a console comparison (six tables) and a unified family struct for use in
% the report and downstream plotting.
%
% Data status flags:
%   [C] confirmed hardware / ICD
%   [P] public spec (website / datasheet)
%   [E] estimated / derived
%   [~] conceptual / indicative only
%
% Run order:
%   MicroNEP_Params.m -> MicroNEP_Model.m -> MicroNEP_Rogue_Public.m ->
%   MicroNEP_Warlock.m -> MicroNEP_SuperMag.m -> this script.
%   MicroNEP_Extended_Profiles.m optional (populates ep, enables Table 4).

if ~exist('NEP','var'),    error('MicroNEP_Family_Compare: NEP not in workspace. Run MicroNEP_Model.m first.'); end
if ~exist('NEP_RP','var'), error('MicroNEP_Family_Compare: NEP_RP not in workspace. Run MicroNEP_Rogue_Public.m first.'); end
if ~exist('NEP_W','var'),  error('MicroNEP_Family_Compare: NEP_W not in workspace. Run MicroNEP_Warlock.m first.'); end
if ~exist('NEP_SM','var'), error('MicroNEP_Family_Compare: NEP_SM not in workspace. Run MicroNEP_SuperMag.m first.'); end

g0 = NEP.const.g0;

%% ── A) ASSEMBLE FAMILY ──────────────────────────────────────────────────
NEP_C = make_nep_C(NEP, g0);

fam          = {NEP_C, NEP_RP, NEP_W, NEP_SM};
short_labels = {'Rogue (conf.)', 'Rogue (pub.)', 'Warlock', 'SuperMagdrive'};
n_fam        = numel(fam);

%% ── B) HEADLINE SPECS ───────────────────────────────────────────────────
headline.label       = short_labels;
headline.I_bit_uNs   = cellfun(@(f) f.I_bit_Ns*1e6,    fam);
headline.I_total_Ns  = cellfun(@(f) f.I_total_Ns,      fam);
headline.F_max_mN    = cellfun(@(f) f.F_max_mN,        fam);
headline.Isp_s       = cellfun(@(f) f.Isp_s,           fam);
headline.m_thr_kg    = cellfun(@(f) f.m_thruster_kg,   fam);
headline.E_store_kJ  = cellfun(@(f) f.E_store_J/1e3,   fam);
headline.t_burst_s   = cellfun(@(f) f.t_burst_s,       fam);
headline.flags.I_bit   = {'[C]','[E]','[E]','[E]'};
headline.flags.I_total = {'[E]','[P]','[P]','[~]'};
headline.flags.F_max   = {'[C]','[P]','[P]','[~]'};
headline.flags.Isp     = {'[C]','[C]','[P]','[~]'};
headline.flags.m_thr   = {'[C]','[C]','[P]','[~]'};
headline.flags.E_store = {'[C]','[C]','[P]','[~]'};

headline.stepup.I_total = headline.I_total_Ns(2:end) ./ headline.I_total_Ns(1);
headline.stepup.F_max   = headline.F_max_mN(2:end)   ./ headline.F_max_mN(1);

%% ── C) OPERATING POINT ──────────────────────────────────────────────────
ops_t.label      = short_labels;
ops_t.P_net_W    = cellfun(@(f) f.ops.P_net_W,    fam);
ops_t.rchg_min   = cellfun(@(f) f.ops.rchg_min,   fam);
ops_t.duty_pct   = cellfun(@(f) f.ops.duty_pct,   fam);
ops_t.F_mN       = cellfun(@(f) f.ops.F_mN,       fam);
ops_t.m_sc_ref   = cellfun(@(f) f.ops.m_sc_ref_kg, fam);
ops_t.dV_1M_ms   = cellfun(@(f) get_dV(f,'dV_1M_ms'),  fam);
ops_t.dV_10M_ms  = cellfun(@(f) get_dV(f,'dV_10M_ms'), fam);
ops_t.dV_50M_ms  = cellfun(@(f) get_dV(f,'dV_50M_ms'), fam);

%% ── D) SYSTEM MASS ──────────────────────────────────────────────────────
mass_t.label        = short_labels;
mass_t.thruster_kg  = cellfun(@(f) f.mass.thruster_kg, fam);
mass_t.power_kg     = cellfun(@(f) f.mass.power_kg,    fam);
mass_t.system_kg    = cellfun(@(f) f.mass.system_kg,   fam);
mass_t.alpha_kgWe   = cellfun(@(f) f.mass.alpha_sys,   fam);

%% ── E) MISSION FEASIBILITY SCREEN (requires ep) ─────────────────────────
feasibility = struct('available', false);
if exist('ep','var')
    feasibility.available     = true;
    feasibility.n_profiles    = numel(ep);
    feasibility.I_req_all_Ns  = arrayfun(@(x) x.I_total_req_Ns, ep);
    feasibility.n_pulse_screen = [1e6, 10e6, 50e6];
    r = NEP.params.rogue;

    feasibility.config_labels = {'Rogue conf. x1','Rogue conf. x3','Rogue conf. x5', ...
                                 'Rogue pub. x1','Warlock x1','SuperMag x1'};
    feasibility.is_fixed = [false false false true true true];
    n_cfg = numel(feasibility.config_labels);
    n_col = numel(feasibility.n_pulse_screen);
    feasibility.n_closed = zeros(n_cfg, n_col);
    % Spec-fixed configs deliver their public total impulse regardless of
    % the pulse column (toolkit convention: I_del = I_total_spec; the
    % spec-equivalent pulse count is cfg.n_pulses_at_spec).
    for c = 1:n_col
        N = feasibility.n_pulse_screen(c);
        I_del = [r.I_bit_Ns*1*N, r.I_bit_Ns*3*N, r.I_bit_Ns*5*N, ...
                 NEP_RP.I_total_Ns, NEP_W.I_total_Ns, NEP_SM.I_total_Ns];
        for cfg_i = 1:n_cfg
            feasibility.n_closed(cfg_i, c) = sum(I_del(cfg_i) >= feasibility.I_req_all_Ns);
        end
    end

    N_ref = 10e6;
    I_del_ref = [r.I_bit_Ns*1*N_ref, r.I_bit_Ns*3*N_ref, r.I_bit_Ns*5*N_ref, ...
                 NEP_RP.I_total_Ns, NEP_W.I_total_Ns, NEP_SM.I_total_Ns];
    feasibility.margin_grid  = nan(n_cfg, feasibility.n_profiles);
    feasibility.I_del_ref_Ns = I_del_ref;
    feasibility.N_ref        = N_ref;
    % NOTE: never name a loop variable 'pi' in this toolkit — scripts share
    % the base workspace and a clobbered pi corrupts every downstream orbit
    % and eclipse calculation (e.g. Summary's eclipse-fraction section).
    for cfg_i = 1:n_cfg
        for p_i = 1:feasibility.n_profiles
            I_req = feasibility.I_req_all_Ns(p_i);
            if I_del_ref(cfg_i) >= I_req
                feasibility.margin_grid(cfg_i, p_i) = (I_del_ref(cfg_i) - I_req) / I_req;
            end
        end
    end

    feasibility.margin_min    = nan(1, n_cfg);
    feasibility.margin_median = nan(1, n_cfg);
    feasibility.margin_max    = nan(1, n_cfg);
    for cfg_i = 1:n_cfg
        mg = feasibility.margin_grid(cfg_i, :);
        mg = mg(~isnan(mg));
        if ~isempty(mg)
            feasibility.margin_min(cfg_i)    = min(mg);
            feasibility.margin_median(cfg_i) = median(mg);
            feasibility.margin_max(cfg_i)    = max(mg);
        end
    end
end

%% ── F) I_BIT TENSION ────────────────────────────────────────────────────
tension.label        = {'Rogue (conf./pub.)', 'Warlock', 'SuperMagdrive'};
tension.I_bit_lo_uNs = [NEP_C.I_bit_Ns*1e6,           NEP_W.cfg.I_bit_from_F*1e6,  NEP_SM.cfg.I_bit_from_F*1e6];
tension.I_bit_hi_uNs = [NEP_RP.cfg.I_bit_from_IT*1e6, NEP_W.cfg.I_bit_from_IT*1e6, NEP_SM.cfg.I_bit_from_IT*1e6];
tension.gap_factor   = tension.I_bit_hi_uNs ./ tension.I_bit_lo_uNs;

%% ── F.5) THRUST-TO-POWER ────────────────────────────────────────────────
% T/P = I_bit / E_pulse (frequency cancels), units mN/kW. Computed from the
% standardised NEP_X.I_bit_Ns / .E_pulse_J fields (single schema, see
% MicroNEP_Variant_Core.m).
tp.label    = [short_labels, {'PTFE-PPT (ref.)', 'Ion (ref.)', 'Hall (ref.)'}];
tp.value    = [NEP_C.T_P_mNkW, NEP_RP.T_P_mNkW, NEP_W.T_P_mNkW, NEP_SM.T_P_mNkW, ...
               NaN, NaN, NaN];
tp.range_lo = [NaN, NaN, NaN, NaN,  5, 30, 50];
tp.range_hi = [NaN, NaN, NaN, NaN, 13, 40, 70];
tp.basis    = {'confirmed', 'derived (I_bit/E_pulse)', 'derived (I_bit/E_pulse)', ...
               'derived (I_bit/E_pulse)', 'literature', 'literature', 'literature'};

%% ── G) PACKAGE FAMILY STRUCT ────────────────────────────────────────────
family.members      = fam;
family.short_labels = short_labels;
family.headline     = headline;
family.ops          = ops_t;
family.mass         = mass_t;
family.tension      = tension;
family.tp           = tp;
family.feasibility  = feasibility;

%% ── H) CONSOLE TABLES ───────────────────────────────────────────────────
fprintf('\nMagdrive family comparison\n');
fprintf('  Flags: [C] confirmed | [P] public spec | [E] estimated | [~] conceptual\n');

% Table 1 — Headline specs
fprintf('\nTable 1 - Headline specs\n');
print_header(short_labels);
print_row_flagged('I_bit',           headline.I_bit_uNs,  '%.0f uN.s', headline.flags.I_bit);
print_row_flagged('I_total',         headline.I_total_Ns, '%.0f Ns',   headline.flags.I_total);
print_row_flagged('F_max',           headline.F_max_mN,   '%.1f mN',   headline.flags.F_max);
print_row_flagged('Isp',             headline.Isp_s,      '%.0f s',    headline.flags.Isp);
print_row_flagged('Mass (thruster)', headline.m_thr_kg,   '%.2f kg',   headline.flags.m_thr);
print_row_flagged('E_store',         headline.E_store_kJ, '%.0f kJ',   headline.flags.E_store);
print_row_plain  ('Burst duration',  headline.t_burst_s,  '%.0f s');
fprintf('  Step-up vs Rogue (conf.):  I_total %.0fx / %.0fx / %.0fx   F_max %.0fx / %.0fx / %.0fx\n', ...
    headline.stepup.I_total, headline.stepup.F_max);

% Table 2 — Operating point
fprintf('\nTable 2 - Operating point (default power source)\n');
print_header(short_labels);
print_row_plain('P_net [W]',      ops_t.P_net_W,  '%.2f');
print_row_plain('Recharge [min]', ops_t.rchg_min, '%.1f');
print_row_plain('Duty cycle [%]', ops_t.duty_pct, '%.2f');
print_row_plain('Thrust [mN]',    ops_t.F_mN,     '%.2f');
print_row_dV   ('dV @ 1M',  ops_t.dV_1M_ms);
print_row_dV   ('dV @ 10M', ops_t.dV_10M_ms);
print_row_dV   ('dV @ 50M', ops_t.dV_50M_ms);
fprintf('  Reference s/c:  %s\n', ...
    strjoin(arrayfun(@(i) sprintf('%s %.0f kg', short_labels{i}, ops_t.m_sc_ref(i)), ...
                     1:n_fam, 'UniformOutput', false), '  |  '));

% Table 3 — System mass
fprintf('\nTable 3 - System mass (thruster + default power unit)\n');
print_header(short_labels);
print_row_plain('Thruster [kg]',     mass_t.thruster_kg, '%.2f');
print_row_plain('Power unit [kg]',   mass_t.power_kg,    '%.1f');
print_row_plain('System total [kg]', mass_t.system_kg,   '%.1f');
print_row_plain('Sp. mass [kg/We]',  mass_t.alpha_kgWe,  '%.2f');

% Table 4 — Mission feasibility screen
if feasibility.available
    fprintf('\nTable 4 - Mission feasibility screen (closure count, %d profiles)\n', feasibility.n_profiles);
    fprintf('  %-22s | %12s | %12s | %12s\n', 'Configuration', '1M pulses', '10M pulses', '50M pulses');
    fprintf('  %s\n', repmat('-', 1, 70));
    for cfg_i = 1:numel(feasibility.config_labels)
        marker = '';
        if feasibility.is_fixed(cfg_i), marker = '*'; end
        fprintf('  %-22s | %4d / %2d %4s | %4d / %2d %4s | %4d / %2d %4s\n', ...
            feasibility.config_labels{cfg_i}, ...
            feasibility.n_closed(cfg_i,1), feasibility.n_profiles, marker, ...
            feasibility.n_closed(cfg_i,2), feasibility.n_profiles, marker, ...
            feasibility.n_closed(cfg_i,3), feasibility.n_profiles, marker);
        if cfg_i == 3, fprintf('  %s\n', repmat('-', 1, 70)); end
    end
    fprintf('  * Delivered impulse fixed at the public I_total spec; closures are\n');
    fprintf('    independent of the pulse columns (shown for layout consistency).\n');

    % Table 4a — Profiles closed per configuration at 10M pulses.
    n_max_print = 12;
    fprintf('\nTable 4a - Profiles closed at 10M pulses (gating configurations)\n');
    prof_labels_4a = {ep.label};
    for cfg_i = 1:numel(feasibility.config_labels)
        n_cl = feasibility.n_closed(cfg_i, 2);
        margins = feasibility.margin_grid(cfg_i, :);
        closed_idx = find(~isnan(margins));
        [~, ord] = sort(feasibility.I_req_all_Ns(closed_idx));
        closed_idx = closed_idx(ord);
        fprintf('  %s (%d / %d):\n', feasibility.config_labels{cfg_i}, n_cl, feasibility.n_profiles);
        if n_cl == 0
            fprintf('    none.\n');
        elseif n_cl > n_max_print
            fprintf('    [%d profiles closed; see heatmap (Fig 29) for full set]\n', n_cl);
        else
            for j = 1:numel(closed_idx)
                p_i = closed_idx(j);
                fprintf('    %-40s  margin %6.2fx\n', prof_labels_4a{p_i}, margins(p_i));
            end
        end
        if cfg_i == 3, fprintf('  %s\n', repmat('-', 1, 60)); end
    end

    % Table 4b — Closure margin summary
    fprintf('\nTable 4b - Closure margin at 10M pulses  (closed profiles only)\n');
    fprintf('  %-22s | %8s | %8s | %8s | %10s\n', ...
        'Configuration', 'min', 'median', 'max', 'closed');
    fprintf('  %s\n', repmat('-', 1, 70));
    for cfg_i = 1:numel(feasibility.config_labels)
        n_cl = feasibility.n_closed(cfg_i, 2);
        if n_cl == 0
            fprintf('  %-22s | %8s | %8s | %8s | %3d / %2d\n', ...
                feasibility.config_labels{cfg_i}, '-', '-', '-', n_cl, feasibility.n_profiles);
        else
            fprintf('  %-22s | %7.2fx | %7.2fx | %7.1fx | %3d / %2d\n', ...
                feasibility.config_labels{cfg_i}, ...
                feasibility.margin_min(cfg_i), ...
                feasibility.margin_median(cfg_i), ...
                feasibility.margin_max(cfg_i), ...
                n_cl, feasibility.n_profiles);
        end
        if cfg_i == 3, fprintf('  %s\n', repmat('-', 1, 70)); end
    end
    fprintf('  Margin >> 1: ample headroom; margin near 0: marginal closure.\n');
else
    fprintf('\nTable 4 - Mission feasibility screen\n');
    fprintf('  (Run MicroNEP_Extended_Profiles.m to populate ep struct.)\n');
end

% Table 5 — I_bit tension
fprintf('\nTable 5 - I_bit derivation gap\n');
fprintf('  %-22s | %14s | %14s | %8s\n', 'Thruster', 'Conservative', 'Optimistic', 'Gap');
fprintf('  %s\n', repmat('-', 1, 66));
for i = 1:numel(tension.label)
    fprintf('  %-22s | %10.0f uN.s | %10.0f uN.s | %6.0fx\n', ...
        tension.label{i}, tension.I_bit_lo_uNs(i), tension.I_bit_hi_uNs(i), tension.gap_factor(i));
end

% Table 6 — Thrust-to-power
% T/P = I_bit / E_pulse (frequency cancels); units mN/kW.
fprintf('\nTable 6 - Thrust-to-power [mN/kW]  (T/P = I_bit / E_pulse)\n');
fprintf('  %-22s | %12s | %s\n', 'Thruster', 'T/P', 'Basis');
fprintf('  %s\n', repmat('-', 1, 70));
for i = 1:numel(tp.label)
    if isnan(tp.value(i))
        v_str = sprintf('%.0f - %.0f', tp.range_lo(i), tp.range_hi(i));
    else
        v_str = sprintf('%.1f', tp.value(i));
    end
    fprintf('  %-22s | %12s | %s\n', tp.label{i}, v_str, tp.basis{i});
end

% Table 7 — Stacking summary
r = NEP.params.rogue; rt = NEP.params.rtg;
tiers_Ns = NEP.params.cfg.req_tiers_Ns;
n_max = NEP.params.cfg.n_stk_max;
fprintf('\nTable 7 - Min n_R to close each tier (n_T = 1, mass-optimal)\n');
fprintf('  %-22s | %5s | %5s | %5s | %5s | %s\n', ...
    'Thruster', 'T1', 'T2', 'T3', '>T3', 'cap [Ns]');
fprintf('  %s\n', repmat('-', 1, 70));
thr_lbl    = {'Rogue (conf.)', 'Rogue (pub.)', 'Warlock', 'SuperMagdrive'};
% Per-unit capability: confirmed Rogue from its pulse budget; public-spec
% variants at their fixed I_total (toolkit convention).
I_per_unit = [r.I_bit_Ns * r.n_pulses_ambition, ...
              NEP_RP.I_total_Ns, NEP_W.I_total_Ns, NEP_SM.I_total_Ns];
I_cap      = [Inf, NEP_RP.I_total_Ns, NEP_W.I_total_Ns, NEP_SM.I_total_Ns];
bands      = [tiers_Ns, tiers_Ns(end)*10];
for ti = 1:numel(thr_lbl)
    cells = cell(1, 4);
    I_unit = I_per_unit(ti);
    for b = 1:4
        nR_needed = ceil(bands(b) / I_unit);
        if nR_needed > n_max
            cells{b} = 'x';
        else
            cells{b} = sprintf('%d', nR_needed);
        end
    end
    if isinf(I_cap(ti)), cap_s = '-';
    else, cap_s = sprintf('%.0f', I_cap(ti)); end
    fprintf('  %-22s | %5s | %5s | %5s | %5s | %s\n', ...
        thr_lbl{ti}, cells{1}, cells{2}, cells{3}, cells{4}, cap_s);
end
fprintf('  T1 <= %.0f Ns | T2 <= %.0f Ns | T3 <= %.0f Ns | >T3 = 10x T3.\n', tiers_Ns);
fprintf('  ''x'' = exceeds %dx%d grid limit.\n', n_max, n_max);

%% ── I) LOAD MESSAGE ─────────────────────────────────────────────────────
n_def_closed = NaN;
if feasibility.available
    n_def_closed = sum(feasibility.n_closed([1,4,5,6], 2));
end
fprintf('\nMicroNEP_Family_Compare complete.\n');
if feasibility.available
    fprintf('  Default config (1x each, 10M pulses): %d / %d profile-closures across the family.\n', ...
        n_def_closed, 4 * feasibility.n_profiles);
end
fprintf('  Structured data available in family.{headline, ops, mass, tension, tp, feasibility}.\n\n');

%% ── LOCAL FUNCTIONS ─────────────────────────────────────────────────────

function nepC = make_nep_C(NEP, g0)
% Wrap the confirmed Rogue model output into the standardised schema used
% by NEP_RP / NEP_W / NEP_SM, so all four can be iterated uniformly.
    r  = NEP.params.rogue;
    rt = NEP.params.rtg;
    m_sc_conf = NEP.params.cfg.m_ref_kg;

    nepC.label         = 'Rogue 3 (confirmed, ICD)';
    nepC.I_bit_Ns      = r.I_bit_Ns;
    nepC.Isp_s         = r.Isp_s;
    nepC.F_max_mN      = r.I_bit_Ns * r.f_Hz * 1e3;
    nepC.T_P_mNkW      = r.T_per_P_mNkW;
    nepC.I_total_Ns    = r.I_bit_Ns * r.n_pulses_ambition;
    nepC.E_store_J     = r.E_store_J;
    nepC.E_pulse_J     = r.E_per_pulse_J;
    nepC.f_max_Hz      = r.f_Hz;
    nepC.t_burst_s     = r.t_burst_max_s;
    nepC.m_thruster_kg = r.mass_kg;
    nepC.m_prop_kg     = r.m_prop_kg;
    nepC.PPU_eta       = r.eta_chain;

    P_net  = rt.P_design_W * NEP.params.mppt.eta - rt.P_parasitic_W;
    rchg_s = r.E_store_J / P_net;
    nepC.ops.P_net_W      = P_net;
    nepC.ops.rchg_s       = rchg_s;
    nepC.ops.rchg_min     = rchg_s / 60;
    nepC.ops.duty_pct     = r.t_burst_max_s / (r.t_burst_max_s + rchg_s) * 100;
    nepC.ops.F_mN         = nepC.F_max_mN;
    nepC.ops.m_sc_ref_kg  = m_sc_conf;
    for ni = [1, 10, 50]
        I_del = r.I_bit_Ns * ni * 1e6;
        m_p   = I_del / (r.Isp_s * g0);
        if m_p >= m_sc_conf
            dV = Inf;
        else
            dV = r.Isp_s * g0 * log(m_sc_conf / (m_sc_conf - m_p));
        end
        nepC.ops.(sprintf('dV_%dM_ms', ni)) = dV;
    end

    nepC.power.type       = 'RTG';
    nepC.power.label      = 'PA Am-241 RTG';
    nepC.power.P_e_W      = rt.P_design_W;
    nepC.power.m_kg       = rt.mass_kg;
    nepC.power.alpha_kgWe = rt.specific_mass_kgWe;
    nepC.power.confirmed  = true;

    nepC.mass.thruster_kg = r.mass_kg;
    nepC.mass.power_kg    = rt.mass_kg;
    nepC.mass.system_kg   = NEP.mass.total_kg;
    nepC.mass.alpha_sys   = NEP.mass.total_kg / rt.P_design_W;

    nepC.data_status.I_bit   = 'confirmed';
    nepC.data_status.I_total = 'derived (I_bit x 10M)';
end

function v = get_dV(f, fn)
    if isfield(f.ops, fn), v = f.ops.(fn); else, v = NaN; end
end

function print_header(labels)
    fprintf('  %-20s | %14s | %14s | %14s | %14s\n', '', labels{:});
    fprintf('  %s\n', repmat('-', 1, 86));
end

function print_row_plain(label, vals, fmt)
    cells = arrayfun(@(v) sprintf(fmt, v), vals, 'UniformOutput', false);
    fprintf('  %-20s | %14s | %14s | %14s | %14s\n', label, cells{:});
end

function print_row_flagged(label, vals, fmt, flags)
    cells = arrayfun(@(i) sprintf([fmt ' %s'], vals(i), flags{i}), ...
                     1:numel(vals), 'UniformOutput', false);
    fprintf('  %-20s | %14s | %14s | %14s | %14s\n', label, cells{:});
end

function print_row_dV(label, vals)
    cells = cell(1, numel(vals));
    for i = 1:numel(vals)
        if isnan(vals(i)),     cells{i} = 'N/A';
        elseif isinf(vals(i)), cells{i} = '>prop lim';
        else,                  cells{i} = sprintf('%.1f m/s', vals(i));
        end
    end
    fprintf('  %-20s | %14s | %14s | %14s | %14s\n', label, cells{:});
end