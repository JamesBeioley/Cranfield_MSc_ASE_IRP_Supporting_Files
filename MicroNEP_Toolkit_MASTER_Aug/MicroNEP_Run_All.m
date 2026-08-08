function MicroNEP_Run_All()
%% =========================================================================
%% MicroNEP_Run_All — Full toolkit runner
%% =========================================================================
% Executes the complete MicroNEP toolkit in the correct dependency order.
% Toggle optional stages on/off with the flags below.
%
% The toolkit is 13 files. This script is the orchestrator; it runs the
% 11 stage scripts below in order. MicroNEP_Variant_Core.m is not a stage
% — it is a shared function called internally by Rogue_Public, Warlock,
% and SuperMag (steps 3-5), so it never appears in the run list itself.
%
% Run order (Extended_Profiles MUST precede Family_Compare so that the ep
% struct is available for Family Tables 4/4a/4b):
%   1.  MicroNEP_Params.m
%   2.  MicroNEP_Model.m
%   3.  MicroNEP_Rogue_Public.m
%   4.  MicroNEP_Warlock.m
%   5.  MicroNEP_SuperMag.m
%   6.  MicroNEP_Extended_Profiles.m  (optional — populates ep / EXT)
%   7.  MicroNEP_Family_Compare.m
%   8.  MicroNEP_Deep_Dives.m
%   9.  MicroNEP_Plots.m              (optional)
%   10. MicroNEP_Thermal_Plots.m      (optional — before Summary so that
%                                      s12 reports burst-scaled thermals)
%   11. MicroNEP_Summary.m
%
% Implementation note: the stages are scripts that share the base
% workspace, and MicroNEP_Params clears it; evalin('base', ...) is
% therefore the one sanctioned use of evalin in this toolkit — a plain
% script runner would have its own stage list wiped by that clear.
%% =========================================================================

%% ── FLAGS ────────────────────────────────────────────────────────────────
run_extended = true;   % Extended_Profiles (35-profile set, ep struct)
run_plots    = true;   % Plots.m (all figures)
run_thermal  = false;  % Thermal_Plots.m

%% ── RUN ──────────────────────────────────────────────────────────────────
t_total = tic;
fprintf('\n========================================\n');
fprintf('  MicroNEP Toolkit — full run\n');
fprintf('========================================\n\n');

run_stage('MicroNEP_Params');
run_stage('MicroNEP_Model');
run_stage('MicroNEP_Rogue_Public');
run_stage('MicroNEP_Warlock');
run_stage('MicroNEP_SuperMag');

if run_extended
    run_stage('MicroNEP_Extended_Profiles');
end

run_stage('MicroNEP_Family_Compare');
run_stage('MicroNEP_Deep_Dives');

if run_plots
    run_stage('MicroNEP_Plots');
end

if run_thermal
    run_stage('MicroNEP_Thermal_Plots');   % before Summary: s12 reads th_scaled
end

run_stage('MicroNEP_Summary');

fprintf('\n========================================\n');
fprintf('  All stages complete  (%.1f s)\n', toc(t_total));
fprintf('========================================\n\n');

end

%% ── LOCAL FUNCTION ───────────────────────────────────────────────────────
function run_stage(name)
    fprintf('>> %s\n', name);
    t0 = tic;
    evalin('base', name);   % sanctioned: stages must execute in base (see header)
    fprintf('   done (%.1f s)\n\n', toc(t0));
end
