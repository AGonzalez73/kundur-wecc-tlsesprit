function out = run_tlsesprit_case(recordFile, caseLabel, opts)
%RUN_TLSESPRIT_CASE  Runs tls_esprit_modes.m on one small-signal record.
%   out = run_tlsesprit_case(recordFile, caseLabel, opts) loads the record
%   (t1, PB79, DwG3) into this function's workspace, runs the script with
%   caseName = caseLabel, saves its figure to results/<caseLabel>/ and
%   returns the reported mode of each signal.
%
%   opts.doNoise    true: Monte Carlo noise test (slowest part)
%   opts.makePlots  true: TLS-ESPRIT figure (window fit and
%                   stabilization diagram), also saved as PNG
%
%   Output fields (one element per signal, PB79 then DwG3):
%     signal, label, f_Hz, zeta, fWin_Hz [min max], zetaWin [min max],
%     zeta30dB [5 % 95 %], NE, fitPct. Damping ratios are per unit.
%
%   The script writes results/ relative to the current folder; run_all.m
%   changes to the repository root first.

    if nargin < 3, opts = struct(); end
    if ~isfield(opts, 'doNoise'),   opts.doNoise   = true; end
    if ~isfield(opts, 'makePlots'), opts.makePlots = true; end

    load(recordFile, 't1', 'PB79', 'DwG3');   %#ok<NASGU> read by the script

    runOpts = struct('caseName', caseLabel, 'doNoise', opts.doNoise, ...
                     'makePlots', opts.makePlots);              %#ok<NASGU>
    tls_esprit_modes;                   % defines res, outDir, snrSet, ...

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
%COLLECT_MODES  Mode reported for each signal (largest NE in its range).
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
