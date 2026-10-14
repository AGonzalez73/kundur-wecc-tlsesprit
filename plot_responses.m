function plot_responses(dataDir, outDir, event)
%PLOT_RESPONSES  Tie-line power P79 and inter-area angle of the four scenarios.
%   plot_responses(dataDir, outDir, event), event = 'pulse', 'fault12' or 'fault9'.

cases = {'pv_p', 'P-control',         [0.066 0.443 0.745], '-', 2.5, 3
         'pv_q', 'Q-control',         [0.866 0.329 0    ], '-', 2.5, 4
         'pv_v', 'V-control',         [0.929 0.694 0.125], '-', 1.5, 1
         'sync', 'Fully synchronous', [0     0     0    ], ':', 2.5, 2};
H = [6.5 6.5 6.175 6.175];

rec = struct('label', {}, 'color', {}, 'style', {}, 'width', {}, 'layer', {}, ...
             't', {}, 'P79', {}, 'dd', {}, 'lost', {});
for c = 1:size(cases, 1)
    f = fullfile(dataDir, [cases{c,1} '_' event '.mat']);
    if ~exist(f, 'file')
        warning('plot_responses:missing', '%s not found, %s skipped.', f, cases{c,2});
        continue
    end
    d  = load(f, 't1', 'PB79', 'dthetaT');
    a1 = 1;
    if strcmp(cases{c,1}, 'sync'), a1 = [1 2]; end
    th = d.dthetaT * 180/pi;
    dd = th(:,a1)*H(a1).'/sum(H(a1)) - th(:,[3 4])*H([3 4]).'/sum(H([3 4]));
    lost = max(abs(dd(d.t1 >= 150) - dd(find(d.t1 >= 149, 1)))) > 180;
    lbl = cases{c,2};
    if lost, lbl = [lbl ' (loss of synchronism)']; end
    rec(end+1) = struct('label', lbl, 'color', cases{c,3}, 'style', cases{c,4}, ...
                        'width', cases{c,5}, 'layer', cases{c,6}, 't', d.t1(:), ...
                        'P79', d.PB79(:), 'dd', dd, 'lost', lost); %#ok<AGROW>
end
if isempty(rec), return; end

if strcmp(event, 'pulse')
    draw(rec, 'P79', [149 160], 1, 'Active power  [MW]', ...
         'Tie-line active power flow  P_{79} (AVR pulse at G3)', 'southeast', fullfile(outDir, 'pulse_P79'));
else
    cyc = sscanf(event, 'fault%d');
    ttl = sprintf(' (three-phase fault, %d cycles)', cyc);
    draw(rec, 'P79', [149 160], 1, 'Active power  [MW]', ...
         ['Tie-line active power flow  P_{79}' ttl], 'southwest', fullfile(outDir, [event '_P79']));
    draw(rec, 'dd', [149 165], 1, 'Angle separation  \Delta\delta  [deg]', ...
         ['Inter-area angle separation' ttl], 'northeast', fullfile(outDir, [event '_angle']));
end
end

function draw(rec, field, tlim, dtTick, ylab, ttl, loc, file)
fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [60 60 1394 840]);
if isprop(fig, 'Theme'), theme(fig, 'light'); end
ax = axes('Parent', fig, 'FontSize', 18, 'LineWidth', 0.75, 'TickDir', 'in', 'Box', 'on', ...
          'XGrid', 'on', 'YGrid', 'on', 'XMinorTick', 'on', 'NextPlot', 'add');
h = {};  yR = [inf -inf];
for k = 1:numel(rec)
    m = rec(k).t >= tlim(1) & rec(k).t <= tlim(2);
    y = rec(k).(field);
    h{end+1} = plot(ax, rec(k).t(m), y(m), 'Color', rec(k).color, 'LineStyle', rec(k).style, ...
                    'LineWidth', rec(k).width, 'DisplayName', rec(k).label); %#ok<AGROW>
    if any(m) && ~(rec(k).lost && strcmp(field, 'dd'))
        yR = [min(yR(1), min(y(m))), max(yR(2), max(y(m)))];
    end
end
h = [h{:}];
[~, o] = sort([rec.layer], 'descend');
set(ax, 'Children', h(o).');

if all(isfinite(yR))
    span = max(diff(yR), eps);
    step = nice_step(span/6);
    yl = [floor((yR(1) - 0.03*span)/step)*step, ceil((yR(2) + 0.03*span)/step)*step];
    set(ax, 'XLim', tlim, 'YLim', yl, 'XTick', ceil(tlim(1)/dtTick)*dtTick:dtTick:tlim(2), ...
            'YTick', (ceil(yl(1)/step)*step:step:yl(2)) + 0);
end
xlabel(ax, 'Time  [s]', 'FontSize', 19.8);
ylabel(ax, ylab, 'FontSize', 19.8);
title(ax, ttl, 'FontSize', 19.8, 'FontWeight', 'bold');
legend(ax, h, {rec.label}, 'Location', loc, 'FontSize', 16, 'Box', 'on', ...
       'Color', 'w', 'EdgeColor', [0.15 0.15 0.15]);
save_figure(fig, file);
end

function s = nice_step(x)
p = 10^floor(log10(x));
r = x/p;
if r < 1.5, s = p; elseif r < 3.5, s = 2*p; elseif r < 7.5, s = 5*p; else, s = 10*p; end
end

function save_figure(fig, base)
if ~isempty(which('exportgraphics'))
    exportgraphics(fig, [base '.png'], 'Resolution', 300);
    exportgraphics(fig, [base '.pdf'], 'ContentType', 'vector');
else
    set(fig, 'PaperPositionMode', 'auto');
    print(fig, [base '.png'], '-dpng', '-r300');
end
end
