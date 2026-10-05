function plot_fault_response(dataDir, outDir)
%PLOT_FAULT_RESPONSE  Figs. 3 and 4: response to the three-phase fault at
%   bus 9 (applied at t = 150 s, cleared after 12 cycles, 200 ms).
%
%   Fig. 3  inter-area angle separation, Eq. (5):
%             Delta_delta(t) = delta_Area1(t) - delta_Area2(t),
%           delta_Area2 = centre of inertia of G3 and G4; delta_Area1 =
%           centre of inertia of G1 and G2 (fully synchronous case) or G1
%           alone (G2 replaced by the PV plant). Computed from DELTAT, the
%           angle delta [deg] of G1-G4 output by the Simscape machine
%           measurement, weighted by H (Table II); (a) 150-200 s, (b)
%           150-161 s.
%   Fig. 4  active power through the tie-line from bus 7 to bus 9, PB79.
%
%   plot_fault_response(dataDir, outDir) reads the records in dataDir
%   (default data/three_phase_fault) and writes PNG and PDF files to outDir
%   (default results). A missing record is reported and skipped.

    here = fileparts(mfilename('fullpath'));
    if nargin < 1 || isempty(dataDir), dataDir = fullfile(here, 'data', 'three_phase_fault'); end
    if nargin < 2 || isempty(outDir),  outDir  = fullfile(here, 'results'); end
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    H = [6.5 6.5 6.175 6.175];          % inertia constants G1-G4 [s], Table II
    % record, legend, colour, line style, machines in Area 1
    cases = {'Kundur_Fault_PVcontrolP.mat', 'P-control',       [0 0.447 0.741],     '-', 1
             'Kundur_Fault_PVcontrolQ.mat', 'Q-control',       [0.850 0.325 0.098], '-', 1
             'Kundur_Fault_PVcontrolV.mat', 'V-control',       [0.929 0.694 0.125], '-', 1
             'Kundur_Fault_FullSync.mat',   'All-synchronous', [0 0 0],             ':', [1 2]};

    rec = struct('label', {}, 'color', {}, 'style', {}, 't', {}, 'dd', {}, 'P79', {});
    for c = 1:size(cases, 1)
        f = fullfile(dataDir, cases{c,1});
        if ~exist(f, 'file')
            warning('plot_fault_response:missing', 'Record %s not found; %s skipped.', f, cases{c,2});
            continue;
        end
        S  = load(f, 't1', 'DELTAT', 'PB79');
        a1 = cases{c,5};  a2 = [3 4];
        dA1 = S.DELTAT(:, a1) * H(a1).' / sum(H(a1));
        dA2 = S.DELTAT(:, a2) * H(a2).' / sum(H(a2));
        rec(end+1) = struct('label', cases{c,2}, 'color', cases{c,3}, 'style', cases{c,4}, ...
                            't', S.t1(:), 'dd', dA1 - dA2, 'P79', S.PB79(:)); %#ok<AGROW>
    end
    if isempty(rec)
        warning('plot_fault_response:none', 'No fault record found in %s.', dataDir);
        return;
    end

    % Fig. 3: (a) full stabilization time, (b) dominant oscillatory period
    fig3 = figure('Name', 'Fig. 3  Inter-area angle separation', 'Color', 'w', ...
                  'Position', [60 120 1150 420]);
    lims = [150 200; 150 161];
    tags = {'(a)', '(b)'};
    for k = 1:2
        ax = subplot(1, 2, k);  hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');
        for r = 1:numel(rec)
            plot(ax, rec(r).t, rec(r).dd, rec(r).style, 'Color', rec(r).color, 'LineWidth', 1);
        end
        xlim(ax, lims(k,:));
        xlabel(ax, {'Time  [s]', tags{k}});  ylabel(ax, '\Delta \delta(t)  [deg]');
        title(ax, 'Inter-area angle separation');
        legend(ax, {rec.label}, 'Location', 'northeast');
    end
    save_figure(fig3, fullfile(outDir, 'fig3_angle_separation'));

    % Fig. 4: tie-line active power P79
    fig4 = figure('Name', 'Fig. 4  Tie-line active power P79', 'Color', 'w', ...
                  'Position', [120 80 600 460]);
    ax = axes('Parent', fig4);  hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');
    for r = 1:numel(rec)
        plot(ax, rec(r).t, rec(r).P79, rec(r).style, 'Color', rec(r).color, 'LineWidth', 1);
    end
    xlim(ax, [149 165]);
    xlabel(ax, 'Time  [s]');  ylabel(ax, 'Active power [MW]');
    title(ax, 'Tie-line active power flow  P_{79}');
    legend(ax, {rec.label}, 'Location', 'southeast');
    save_figure(fig4, fullfile(outDir, 'fig4_tieline_power'));

    fprintf('Figs. 3 and 4 written to %s (%d of %d records).\n', outDir, numel(rec), size(cases, 1));
end

function save_figure(fig, base)
%SAVE_FIGURE  PNG (300 dpi) and vector PDF cropped to the figure size.
    set(fig, 'PaperPositionMode', 'auto', 'PaperUnits', 'inches');
    pos = get(fig, 'PaperPosition');
    set(fig, 'PaperSize', pos(3:4), 'PaperPosition', [0 0 pos(3:4)]);
    print(fig, [base '.png'], '-dpng', '-r300');
    print(fig, [base '.pdf'], '-dpdf', '-painters');
end
