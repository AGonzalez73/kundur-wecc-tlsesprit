function T = run_all(varargin)
%RUN_ALL  Main script: reproduces Table I and Figs. 3-4 of
%   A. González Domínguez, H. García Viveros, M. A. Arjona López and
%   C. Hernández, "Impact of Photovoltaic Power Plant Control Modes on
%   Small-Signal and Transient Stability in Low-Inertia Power Systems,"
%   IEEE Latin America Transactions, 2026.
%
%   run_all                     full run: TLS-ESPRIT on the four small-signal
%                               records (window sweep and Monte Carlo noise
%                               test included), then Figs. 3-4
%   run_all('noise', false)     skips the noise test (about a minute)
%   run_all('plots', false)     no figures
%   T = run_all(...)            also returns Table I as a MATLAB table
%
%   Outputs in results/ (created on the first run):
%     table1.csv                         identified modes next to Table I
%     <case>/summary.txt                 TLS-ESPRIT summary of each scenario
%     <case>/PB79_modes.csv, DwG3_modes.csv, tlsesprit_modes.png
%     fig3_angle_separation.png/.pdf, fig4_tieline_power.png/.pdf
%
%   MATLAB R2018b or later, no toolboxes.

    p = inputParser;
    addParameter(p, 'noise', true, @(x) islogical(x) || isnumeric(x));
    addParameter(p, 'plots', true, @(x) islogical(x) || isnumeric(x));
    parse(p, varargin{:});
    opts = struct('doNoise', logical(p.Results.noise), 'makePlots', logical(p.Results.plots));

    root   = fileparts(mfilename('fullpath'));
    oldDir = cd(root);                         % results/ is written here
    restoreDir = onCleanup(@() cd(oldDir));    %#ok<NASGU>

    % Scenario, record in data/, and Table I of the paper (f in Hz, zeta pu):
    %            inter-area f, zeta     local Area 2 f, zeta
    cases = {'FullSync',  'Kundur_FullSync.mat',   [0.612 0.256  1.490 0.318]
             'P-control', 'Kundur_PVcontrolP.mat', [0.624 0.228  1.491 0.319]
             'Q-control', 'Kundur_PVcontrolQ.mat', [0.621 0.234  1.490 0.319]
             'V-control', 'Kundur_PVcontrolV.mat', [0.636 0.216  1.498 0.315]};
    nC = size(cases, 1);

    %% Small-signal analysis: TLS-ESPRIT on the Vref pulse at G3 (Table I)
    got = nan(nC, 4);  win = nan(nC, 8);  z30 = nan(nC, 4);
    for c = 1:nC
        fprintf('\n=================== %s ===================\n', cases{c,1});
        r = run_case(fullfile(root, 'data', cases{c,2}), cases{c,1}, opts);
        for s = 1:2       % 1: PB79 -> inter-area, 2: DwG3 -> local Area 2
            got(c, 2*s-1:2*s) = [r(s).f_Hz, r(s).zeta];
            win(c, 4*s-3:4*s) = [r(s).fWin_Hz, r(s).zetaWin];
            z30(c, 2*s-1:2*s) = r(s).zeta30dB;
        end
    end

    paper = cell2mat(cases(:,3));
    T = table(cases(:,1), got(:,1), got(:,2), paper(:,1), paper(:,2), ...
              got(:,3), got(:,4), paper(:,3), paper(:,4), ...
              win(:,1), win(:,2), win(:,3), win(:,4), z30(:,1), z30(:,2), ...
              win(:,5), win(:,6), win(:,7), win(:,8), z30(:,3), z30(:,4), ...
        'VariableNames', {'Case', ...
              'fInter_Hz', 'zetaInter', 'fInter_paper', 'zetaInter_paper', ...
              'fLocal_Hz', 'zetaLocal', 'fLocal_paper', 'zetaLocal_paper', ...
              'fInterWinMin', 'fInterWinMax', 'zetaInterWinMin', 'zetaInterWinMax', ...
              'zetaInter30dB_p05', 'zetaInter30dB_p95', ...
              'fLocalWinMin', 'fLocalWinMax', 'zetaLocalWinMin', 'zetaLocalWinMax', ...
              'zetaLocal30dB_p05', 'zetaLocal30dB_p95'});
    if ~exist('results', 'dir'), mkdir('results'); end
    writetable(T, fullfile('results', 'table1.csv'));

    fprintf('\n================ Table I: identified vs. paper ================\n');
    fprintf('%-10s | %-24s | %-24s\n', '', 'Inter-area (PB79)', 'Local Area 2 (DwG3)');
    fprintf('%-10s | %-11s %-12s | %-11s %-12s\n', 'Case', 'f [Hz]', 'zeta', 'f [Hz]', 'zeta');
    for c = 1:nC
        fprintf('%-10s | %.4f      %.4f       | %.4f      %.4f\n', cases{c,1}, got(c,:));
        fprintf('%-10s | %.3f       %.3f        | %.3f       %.3f      (paper)\n', '', paper(c,:));
    end
    d = abs(got - paper);
    fprintf(['Largest difference to the paper: %.4f Hz and %.4f in zeta (inter-area), ' ...
             '%.4f Hz and %.4f in zeta (local)\n'], max(d(:,1)), max(d(:,2)), max(d(:,3)), max(d(:,4)));
    fprintf('Written: %s\n', fullfile(root, 'results', 'table1.csv'));

    %% Transient stability: three-phase fault at bus 9 (Figs. 3 and 4)
    if opts.makePlots
        plot_fault_response(fullfile(root, 'data'), fullfile(root, 'results'));
    end
    if nargout == 0, clear T; end      % no "ans = table" dump in the console
end

%% =====================================================================
%  Local functions
%% =====================================================================
function out = run_case(recordFile, caseLabel, opts)
%RUN_CASE  Runs tls_esprit_modes.m on one record. The record (t1, PB79,
%   DwG3) is loaded into this workspace, where the script reads it;
%   runOpts presets caseName, doNoise and makePlots in the script. The
%   script's figure is saved to results/<caseLabel>/tlsesprit_modes.png.
    res = [];  outDir = '';  snrSet = [];     % set by the script below
    load(recordFile, 't1', 'PB79', 'DwG3');
    runOpts = struct('caseName', caseLabel, 'doNoise', opts.doNoise, ...
                     'makePlots', opts.makePlots);                  %#ok<NASGU>
    tls_esprit_modes;

    if opts.makePlots
        hFig = get(groot, 'CurrentFigure');
        if ~isempty(hFig)
            set(hFig, 'Position', [80 80 1300 820], 'PaperPositionMode', 'auto');
            print(hFig, fullfile(outDir, 'tlsesprit_modes.png'), '-dpng', '-r150');
        end
    end
    out = collect_modes(res, snrSet);
end

function out = collect_modes(res, snrSet)
%COLLECT_MODES  Mode reported for each signal (largest NE in its range):
%   f [Hz], zeta, window-sweep ranges and 5-95 % zeta at 30 dB (per unit).
    i30 = find(snrSet == 30, 1);
    out = struct('signal', {}, 'label', {}, 'f_Hz', {}, 'zeta', {}, 'fWin_Hz', {}, ...
                 'zetaWin', {}, 'zeta30dB', {}, 'NE', {}, 'fitPct', {});
    for s = 1:numel(res)
        R = res(s);
        o = struct('signal', R.name, 'label', R.label, 'f_Hz', NaN, 'zeta', NaN, ...
                   'fWin_Hz', [NaN NaN], 'zetaWin', [NaN NaN], 'zeta30dB', [NaN NaN], ...
                   'NE', NaN, 'fitPct', R.fit);
        if ~isempty(R.iT)
            m = R.modes;  k = R.iT;
            o.f_Hz    = m.Freq_Hz(k);
            o.zeta    = m.Damping_pct(k) / 100;
            o.fWin_Hz = [m.FminWin_Hz(k), m.FmaxWin_Hz(k)];
            o.zetaWin = [m.ZminWin_pct(k), m.ZmaxWin_pct(k)] / 100;
            o.NE      = m.NE(k);
            if ~isempty(i30), o.zeta30dB = R.zNoise(i30, :) / 100; end
        end
        out(end+1) = o; %#ok<AGROW>
    end
end
