function run_all(varargin)
%RUN_ALL  Reproduces the results of the paper from the records in data/.
%   run_all                     operating point, Table I (TLS-ESPRIT) and figures
%   run_all('noise', false)     skips the Monte Carlo noise test (about a minute)
%   run_all('plots', false)     no figures
%   run_all('simulate', true)   regenerates data/ with the Simulink models first

p = inputParser;
addParameter(p, 'noise', true);
addParameter(p, 'plots', true);
addParameter(p, 'simulate', false);
parse(p, varargin{:});
opt = p.Results;

root    = fileparts(mfilename('fullpath'));
dataDir = fullfile(root, 'data');
outDir  = fullfile(root, 'results');
figDir  = fullfile(outDir, 'figures');
addpath(root, fullfile(root, 'models'));
if ~exist(figDir, 'dir'), mkdir(figDir); end

if opt.simulate
    simulate_cases;
end

cases = {'sync', 'Fully synchronous'
         'pv_p', 'P-control'
         'pv_q', 'Q-control'
         'pv_v', 'V-control'};

operating_point(dataDir, outDir, cases);
T = table1(dataDir, outDir, cases, opt);

if opt.plots
    plot_damping(T, figDir, opt.noise);
    for ev = {'pulse', 'fault12', 'fault9'}
        plot_responses(dataDir, figDir, ev{1});
    end
end
fprintf('\nResults written to %s\n', outDir);
end

function operating_point(dataDir, outDir, cases)
fprintf('\nOperating point at t = 149 s\n');
fprintf('%-14s %9s %10s %12s %8s %8s %9s\n', 'Record', 'P79[MW]', 'P_bus6[MW]', 'Q_bus6[MVAr]', ...
        'V7[pu]', 'V9[pu]', 'f[Hz]');
rows = {};
for c = 1:size(cases, 1)
    for ev = {'pulse', 'fault12', 'fault9'}
        name = [cases{c,1} '_' ev{1}];
        file = fullfile(dataDir, [name '.mat']);
        if ~exist(file, 'file'), continue; end
        d = load(file);
        i = find(d.t1 >= 149, 1);
        if isfield(d, 'PB5')
            P6 = d.PB5(i);  Q6 = d.PB5Q(i);
        else
            P6 = d.PB2(i);  Q6 = d.QB2(i);
        end
        x = [d.PB79(i), P6, Q6, d.VB79(i,1), d.VB79(i,2), 60*(1 + d.dwT(i,1))];
        fprintf('%-14s %9.2f %10.2f %12.2f %8.4f %8.4f %9.4f\n', name, x);
        rows(end+1, :) = [{name}, num2cell(x)]; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'Record', 'P79_MW', 'Pbus6_MW', 'Qbus6_MVAr', ...
               'V7_pu', 'V9_pu', 'f_Hz'});
writetable(T, fullfile(outDir, 'operating_point.csv'));
end

function T = table1(dataDir, outDir, cases, opt)
n = size(cases, 1);
v = nan(n, 16);
for c = 1:n
    rec = load(fullfile(dataDir, [cases{c,1} '_pulse.mat']), 't1', 'PB79', 'DwG3');
    fprintf('\n=================== %s ===================\n', cases{c,2});
    res = tls_esprit_modes(rec, cases{c,2}, opt.noise, opt.plots, fullfile(outDir, cases{c,1}));
    for q = 1:numel(res)
        R = res(q);  m = R.modes;  k = R.iT;  s = 1 + strcmp(R.name, 'DwG3');
        if isempty(k), continue; end
        z30 = R.zNoise(R.snrSet == 30, :);
        v(c, 8*s-7:8*s) = [m.Freq_Hz(k), m.Damping_pct(k), m.FminWin_Hz(k), m.FmaxWin_Hz(k), ...
                           m.ZminWin_pct(k), m.ZmaxWin_pct(k), z30] .* [1 0.01 1 1 0.01 0.01 0.01 0.01];
    end
end
names = {'f', 'zeta', 'fWinMin', 'fWinMax', 'zetaWinMin', 'zetaWinMax', 'zeta30dB_p05', 'zeta30dB_p95'};
T = cell2table([cases(:,2), num2cell(v)], 'VariableNames', ...
               [{'Case'}, strcat('Inter_', names), strcat('Local_', names)]);
writetable(T, fullfile(outDir, 'table1.csv'));

fprintf('\nTable I. Electromechanical modes (f in Hz, zeta in pu; window-sweep range in brackets)\n');
fprintf('%-18s | %-30s | %-30s\n', '', 'Inter-area (P79)', 'Local Area 2 (DwG3)');
for c = 1:n
    fprintf('%-18s | %.4f  %.4f [%.4f-%.4f] | %.4f  %.4f [%.4f-%.4f]\n', cases{c,2}, ...
            v(c,[1 2 5 6]), v(c,[9 10 13 14]));
end
if opt.noise
    fprintf('\nzeta 5-95 %% interval at 30 dB SNR (inter-area / local)\n');
    C = [cases(:,2), num2cell(v(:,[7 8 15 16]))].';
    fprintf('%-18s | %.4f-%.4f | %.4f-%.4f\n', C{:});
end
end

function plot_damping(T, figDir, withNoise)
fig = figure('Color', 'w', 'Position', [100 100 1200 420]);
if isprop(fig, 'Theme'), theme(fig, 'light'); end
mode = {'Inter', 'Inter-area mode (P_{79})'; 'Local', 'Local mode of Area 2 (\Delta\omega_{G3})'};
n = height(T);  y = n:-1:1;
Z = cell(2, 3);
for s = 1:2
    Z{s,1} = 100*T.([mode{s,1} '_zeta']);
    Z{s,2} = 100*[T.([mode{s,1} '_zetaWinMin']), T.([mode{s,1} '_zetaWinMax'])];
    Z{s,3} = 100*[T.([mode{s,1} '_zeta30dB_p05']), T.([mode{s,1} '_zeta30dB_p95'])];
    if ~withNoise, Z{s,3}(:) = NaN; end
end
span = max(cellfun(@(a, b, c) max([a; b(:); c(:)]) - min([a; b(:); c(:)]), Z(:,1), Z(:,2), Z(:,3)));
span = max(4, 1.3*span);
for s = 1:2
    ax = subplot(1, 2, s);  axs(s) = ax;  hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');
    z = Z{s,1};  w = Z{s,2};  nz = Z{s,3};
    for c = 1:n
        plot(ax, nz(c,:), [y(c) y(c)], '-', 'Color', [0.75 0.82 0.92], 'LineWidth', 9);
        plot(ax, w(c,:), [y(c) y(c)], '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.5);
    end
    plot(ax, z, y, 'o', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'MarkerSize', 8);
    text(ax, z, y + 0.25, arrayfun(@(x) sprintf('%.2f', x), z, 'UniformOutput', false), ...
         'FontSize', 11, 'HorizontalAlignment', 'center');
    c0 = (min([z; w(:); nz(:)]) + max([z; w(:); nz(:)]))/2;
    set(ax, 'YTick', 1:n, 'YTickLabel', flipud(T.Case), 'YLim', [0.4 n + 0.6], ...
            'XLim', c0 + span*[-0.5 0.5], 'FontSize', 12);
    if s == 2, set(ax, 'YTickLabel', {}); end
    xlabel(ax, 'Damping ratio  \zeta  [%]');
    title(ax, mode{s,2});
end
ax = axs(1);
h = [plot(ax, NaN, NaN, 'o', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74]), ...
     plot(ax, NaN, NaN, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.5)];
lbl = {'Identified', 'Window sweep'};
if withNoise
    h(3) = plot(ax, NaN, NaN, '-', 'Color', [0.75 0.82 0.92], 'LineWidth', 9);
    lbl{3} = '30 dB noise, 5-95 %';
end
legend(ax, h, lbl, 'Location', 'southeast', 'FontSize', 10);
print(fig, fullfile(figDir, 'damping_comparison.png'), '-dpng', '-r200');
end
