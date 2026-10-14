function res = tls_esprit_modes(rec, caseName, doNoise, makePlots, outDir)
%TLS_ESPRIT_MODES  Electromechanical modes of a ringdown record by TLS-ESPRIT.
%   res = tls_esprit_modes(rec, caseName, doNoise, makePlots, outDir)
%   rec is a struct with fields t1, PB79 and DwG3 (one *_pulse.mat record).

if nargin < 3 || isempty(doNoise),   doNoise = true;   end
if nargin < 4 || isempty(makePlots), makePlots = true; end
if nargin < 5 || isempty(outDir),    outDir = fullfile('results', caseName); end

%% Settings
sigSpec = { 'PB79', 'Inter-area',   [0.1 1.0], 0.5
            'DwG3', 'Local Area 2', [1.0 2.0], 0.1 };

tDist = 150;   tPulse = 0.1;
fSlow = 0.62;  nCyc   = 4;
decim = 1;

detrendMode = 'linear';
fBand       = [0.1 2.0];
rStab       = 2:60;
tolF        = 0.01;
tolZ        = 0.05;
minFrac     = 0.30;
neDominant  = 0.10;
matchTol    = 0.05;

doSweep = true;   dT0Set = 0:0.1:0.5;   TwSet = (3:0.25:4)/fSlow;
snrSet  = [40 30 20];  nMC = 200;  rngSeed = 0;

%% Data
tAll = double(rec.t1(:));
nSig = size(sigSpec, 1);
Yall = cell(1, nSig);
for q = 1:nSig
    Yall{q} = double(rec.(sigSpec{q,1}));  Yall{q} = Yall{q}(:);
end
if decim > 1
    [tAll, Yall] = decimate_zp(tAll, Yall, decim);
end
Tw  = nCyc / fSlow;
t0v = tDist + tPulse + cell2mat(sigSpec(:,4)).';
if max(t0v) + max([Tw TwSet]) + max(dT0Set) > tAll(end)
    error('The windows exceed the record (%.2f s).', tAll(end));
end
rng(rngSeed);

%% Steps 1-4: identification per signal
res = struct([]);
for q = 1:nSig
    [tq, yq, fs] = get_window(tAll, Yall{q}, t0v(q), t0v(q) + Tw);
    yd = detrend_local(yq, detrendMode);
    N  = numel(yd);  M = floor(N/2);
    U  = hankel_svd(yd, M);

    [md, stab] = stabilization(U, M, fs, rStab, fBand, tolF, tolZ, minFrac);
    if height(md) == 0
        warning('%s: no stable mode in %.1f-%.1f Hz; skipped.', sigSpec{q,1}, fBand);
        continue;
    end

    [md.NE, A0, sg, yhat] = mode_fit(yd, fs, md.Freq_Hz, md.Damping_pct);
    md.Dominant = md.NE >= neDominant;
    rg  = sigSpec{q,3};
    inR = find(md.Freq_Hz >= rg(1) & md.Freq_Hz < rg(2) & md.NE > 0);
    iT  = [];
    if ~isempty(inR), [~, b] = max(md.NE(inR)); iT = inR(b); end

    Tdn = NaN;  sN = NaN;
    if ~isempty(iT)
        [~, yp] = get_window(tAll, Yall{q}, tDist - 1 - Tw, tDist - 1);
        sN  = sqrt(mean(detrend_local(yp, detrendMode).^2));
        Tdn = log(A0(iT)/sN) / (-sg(iT));
    end

    j = numel(res) + 1;
    res(j).name = sigSpec{q,1};  res(j).label = sigSpec{q,2};  res(j).range = rg;
    res(j).t0 = t0v(q);  res(j).yAll = Yall{q};  res(j).t = tq;  res(j).y = yq;
    res(j).yd = yd;  res(j).yhat = yhat;  res(j).fs = fs;  res(j).N = N;  res(j).M = M;
    res(j).modes = md;  res(j).stab = stab;  res(j).iT = iT;
    res(j).fit = 100*(1 - norm(yd - yhat)/norm(yd));
    res(j).Tdn = Tdn;  res(j).sN = sN;  res(j).nWin = 0;
    res(j).snrSet = snrSet;  res(j).det = nan(size(snrSet));  res(j).zNoise = nan(numel(snrSet), 2);
end
if isempty(res), error('No signal produced a stable mode.'); end

%% Step 5: window sweep and noise test
for q = 1:numel(res)
    m  = res(q).modes;  nm = height(m);  iD = find(m.Dominant);
    fLo = m.Freq_Hz;  fHi = fLo;  zLo = m.Damping_pct;  zHi = zLo;  hit = zeros(nm, 1);
    if doSweep
        for a = dT0Set
            for b = TwSet
                [~, yw, fsw] = get_window(tAll, res(q).yAll, res(q).t0 + a, res(q).t0 + a + b);
                ydw = detrend_local(yw, detrendMode);  Mw = floor(numel(ydw)/2);
                mw  = stabilization(hankel_svd(ydw, Mw), Mw, fsw, rStab, fBand, tolF, tolZ, minFrac);
                res(q).nWin = res(q).nWin + 1;
                if height(mw) == 0, continue; end
                [fm, zm] = match_modes(m.Freq_Hz(iD), mw.Freq_Hz, mw.Damping_pct, matchTol);
                okm = ~isnan(fm(:));  ok = iD(okm);  fm = fm(:);  zm = zm(:);
                fLo(ok) = min(fLo(ok), fm(okm));  fHi(ok) = max(fHi(ok), fm(okm));
                zLo(ok) = min(zLo(ok), zm(okm));  zHi(ok) = max(zHi(ok), zm(okm));
                hit(ok) = hit(ok) + 1;
            end
        end
    end
    nd = ~m.Dominant;  fLo(nd) = NaN;  fHi(nd) = NaN;  zLo(nd) = NaN;  zHi(nd) = NaN;
    res(q).modes.FminWin_Hz  = fLo;  res(q).modes.FmaxWin_Hz  = fHi;
    res(q).modes.ZminWin_pct = zLo;  res(q).modes.ZmaxWin_pct = zHi;
    res(q).modes.WinFound    = hit;

    if doNoise && ~isempty(res(q).iT)
        R = res(q);  fT = R.modes.Freq_Hz(R.iT);  rmsY = sqrt(mean(R.yd.^2));
        for u = 1:numel(snrSet)
            zN = nan(nMC, 1);
            for i = 1:nMC
                ydn = detrend_local(R.y + rmsY*10^(-snrSet(u)/20)*randn(R.N,1), detrendMode);
                mn  = stabilization(hankel_svd(ydn, R.M), R.M, R.fs, rStab, fBand, tolF, tolZ, minFrac);
                if height(mn) > 0
                    [~, zN(i)] = match_modes(fT, mn.Freq_Hz, mn.Damping_pct, matchTol);
                end
            end
            res(q).det(u) = 100*mean(~isnan(zN));
            zs = sort(zN(~isnan(zN)));
            if ~isempty(zs), res(q).zNoise(u,:) = reshape(zs(max(1, round([0.05 0.95]*numel(zs)))), 1, 2); end
        end
    end
end

%% Summary
S = {sprintf('Case: %s   fs = %.0f Hz   Tw = %.2f s   %d windows in the sweep', ...
             caseName, res(1).fs, Tw, numel(dT0Set)*numel(TwSet)*doSweep), ''};
for q = 1:numel(res)
    R = res(q);  m = R.modes;
    S{end+1} = sprintf('%s -> %s mode, window %.3f-%.3f s', R.name, R.label, R.t0, R.t0 + Tw); %#ok<AGROW>
    if isempty(R.iT)
        S{end+1} = sprintf('   no mode with energy in %.1f-%.1f Hz', R.range); %#ok<AGROW>
    else
        k = R.iT;
        S{end+1} = sprintf('   f    = %.4f Hz   (windows: %.4f-%.4f)', m.Freq_Hz(k), m.FminWin_Hz(k), m.FmaxWin_Hz(k)); %#ok<AGROW>
        S{end+1} = sprintf('   zeta = %.2f %%     (windows: %.2f-%.2f)', m.Damping_pct(k), m.ZminWin_pct(k), m.ZmaxWin_pct(k)); %#ok<AGROW>
        S{end+1} = sprintf('   NE = %.2f, stable in %d of %d orders, found in %d of %d windows, fit %.1f %% (%d modes)', ...
            m.NE(k), m.StableOrders(k), m.OrdersUsed(k), m.WinFound(k), R.nWin, R.fit, height(m)); %#ok<AGROW>
        if doNoise
            for u = 1:numel(snrSet)
                S{end+1} = sprintf('   %2.0f dB noise: found in %5.1f %% of %d runs, zeta 5-95 %%: %.2f-%.2f', ...
                    snrSet(u), R.det(u), nMC, R.zNoise(u,1), R.zNoise(u,2)); %#ok<AGROW>
            end
        end
        if ~isnan(R.Tdn)
            S{end+1} = sprintf('   reaches the pre-event noise floor (%.2g rms) %.1f s after the window start', ...
                R.sN, R.Tdn); %#ok<AGROW>
        end
    end
    isT = false(height(m), 1);  isT(R.iT) = true;
    oth = find(m.Dominant & ~isT);
    if ~isempty(oth)
        txt = arrayfun(@(k) sprintf('%.4f Hz, %.2f %% (NE %.2f)', m.Freq_Hz(k), m.Damping_pct(k), ...
                       m.NE(k)), oth, 'UniformOutput', false);
        S{end+1} = ['   other dominant modes: ' strjoin(txt(:).', ';  ')]; %#ok<AGROW>
    end
    S{end+1} = ''; %#ok<AGROW>
end
S{end+1} = 'Same eigenvalue in the other signal:';
for q = 1:numel(res)
    if isempty(res(q).iT), continue; end
    k = res(q).iT;  fT = res(q).modes.Freq_Hz(k);
    for p = setdiff(1:numel(res), q)
        mp = res(p).modes;  d = abs(mp.Freq_Hz - fT)/fT;  d(~mp.Dominant) = Inf;
        [d, jm] = min(d);
        if d < matchTol
            S{end+1} = sprintf('   %s (%s): %.4f Hz, %.2f %%  |  %s: %.4f Hz, %.2f %% (windows: %.2f-%.2f)', ...
                res(q).label, res(q).name, fT, res(q).modes.Damping_pct(k), res(p).name, ...
                mp.Freq_Hz(jm), mp.Damping_pct(jm), mp.ZminWin_pct(jm), mp.ZmaxWin_pct(jm)); %#ok<AGROW>
        else
            S{end+1} = sprintf('   %s (%s): %.4f Hz  |  %s: not dominant', res(q).label, ...
                res(q).name, fT, res(p).name); %#ok<AGROW>
        end
    end
end
fprintf('\n');  fprintf('%s\n', S{:});

%% Save
if ~exist(outDir, 'dir'), mkdir(outDir); end
for q = 1:numel(res)
    writetable(res(q).modes, fullfile(outDir, [res(q).name '_modes.csv']));
end
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', S{:});
fprintf(fid, ['\nSettings: tDist %g s, tPulse %g s, tSkip %s s, Tw %.4f s (nCyc %g, fSlow %g Hz), ' ...
              'decim %d, detrend %s, band %g-%g Hz, orders %d-%d, tolF %g, tolZ %g, minFrac %g, ' ...
              'neDominant %g, matchTol %g, dT0 %s, Tw sweep %s, SNR %s dB, nMC %d, seed %d\n'], ...
        tDist, tPulse, mat2str(cell2mat(sigSpec(:,4)).'), Tw, nCyc, fSlow, decim, detrendMode, ...
        fBand, rStab(1), rStab(end), tolF, tolZ, minFrac, neDominant, matchTol, ...
        mat2str(dT0Set), mat2str(TwSet, 4), mat2str(snrSet), nMC, rngSeed);
fclose(fid);

if makePlots
    plot_identification(res, caseName, rStab, fBand, fullfile(outDir, 'tlsesprit.png'));
end
end

function plot_identification(res, caseName, rStab, fBand, file)
fig = figure('Name', ['TLS-ESPRIT: ' caseName], 'Color', 'w', 'Position', [80 80 1300 820]);
if isprop(fig, 'Theme'), theme(fig, 'light'); end
nR = numel(res);
for q = 1:nR
    R = res(q);  m = R.modes;
    ax = subplot(2, nR, q);  hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');
    plot(ax, R.t, R.yd, 'k', 'LineWidth', 1);
    plot(ax, R.t, R.yhat, '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
    xlim(ax, R.t([1 end]));
    xlabel(ax, 'Time [s]');  ylabel(ax, [R.name ' (detrended)']);
    title(ax, sprintf('%s: %s, fit of %d modes %.1f %%', caseName, R.name, height(m), R.fit));
    legend(ax, {'Simulation', 'Identified modes'}, 'Location', 'northeast');

    ax = subplot(2, nR, nR + q);  hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');
    for k = 1:numel(R.stab)
        st = R.stab(k).isStable;
        plot(ax, R.stab(k).f(~st), R.stab(k).r*ones(nnz(~st),1), 'o', 'Color', [.75 .75 .75], 'MarkerSize', 3);
        plot(ax, R.stab(k).f(st),  R.stab(k).r*ones(nnz(st),1),  '+', 'Color', [0 0.45 0.74], 'MarkerSize', 5);
    end
    for k = find(m.Dominant).'
        plot(ax, m.Freq_Hz(k)*[1 1], rStab([1 end]), '--', 'Color', [.5 .5 .5]);
    end
    h = [plot(ax, NaN, NaN, '+', 'Color', [0 0.45 0.74]), plot(ax, NaN, NaN, 'o', 'Color', [.75 .75 .75])];
    lbl = {'Stable pole', 'Unstable pole'};
    if ~isempty(R.iT)
        h(end+1) = plot(ax, m.Freq_Hz(R.iT)*[1 1], rStab([1 end]), 'r-', 'LineWidth', 1.5);
        lbl{end+1} = sprintf('%s: %.4f Hz, %.2f %%', R.label, m.Freq_Hz(R.iT), m.Damping_pct(R.iT));
    end
    xlim(ax, fBand);  ylim(ax, rStab([1 end]));
    xlabel(ax, 'Frequency [Hz]');  ylabel(ax, 'Model order');
    title(ax, sprintf('%s: stabilization diagram', R.name));
    legend(ax, h, lbl, 'Location', 'southeast');
end
print(fig, file, '-dpng', '-r150');
end

function [t, y, fs] = get_window(tAll, yAll, ta, tb)
idx = tAll >= ta - 1e-9 & tAll <= tb + 1e-9;
[t, iu] = unique(tAll(idx), 'last');  y = yAll(idx);  y = y(iu);
dt = diff(t);
if numel(t) < 20 || max(abs(dt - mean(dt)))/mean(dt) > 1e-6
    error('Window [%.2f, %.2f] s: too short or not uniformly sampled.', ta, tb);
end
fs = 1/mean(dt);
end

function [t, Y] = decimate_zp(t, Y, q)
L  = 16*q + 1;  x = (0.8/q) * ((0:L-1).' - (L-1)/2);
sn = ones(L, 1);  nz = x ~= 0;  sn(nz) = sin(pi*x(nz)) ./ (pi*x(nz));
h  = sn .* (0.54 - 0.46*cos(2*pi*(0:L-1).'/(L-1)));
h  = h / sum(h);
for k = 1:numel(Y)
    y    = conv(Y{k}, h, 'same');
    y    = flipud(conv(flipud(y), h, 'same'));
    Y{k} = y(1:q:end);
end
t = t(1:q:end);
end

function yd = detrend_local(y, mode)
N = numel(y);
switch lower(mode)
    case 'constant', A = ones(N,1);
    case 'linear',   A = [ones(N,1), (0:N-1).'];
    otherwise, error('Unknown detrend mode: %s', mode);
end
yd = y - A*(A\y);
end

function U = hankel_svd(yd, M)
yn = yd / std(yd);
[U, ~, ~] = svd(hankel(yn(1:M), yn(M:end)), 'econ');
end

function z = esprit_poles(U, M, r)
r  = min(r, floor((M-1)/2));
Us = U(:, 1:r);
[~, ~, F] = svd([Us(1:M-1,:), Us(2:M,:)], 'econ');
z = eig(-F(1:r, r+1:end) / F(r+1:end, r+1:end));
z = z(abs(z) > 1e-12);
end

function P = band_poles(z, fs, fBand)
s = log(z(:))*fs;  f = imag(s)/(2*pi);  ze = -real(s)./abs(s);
k = f >= fBand(1) & f <= fBand(2) & ze > 0;
P = [f(k), ze(k)];
if isempty(P), P = zeros(0, 2); return; end
P = sortrows(P, 1);
end

function [modes, stab] = stabilization(U, M, fs, orders, fBand, tolF, tolZ, minFrac)
orders = orders(orders <= floor((M-1)/2));
nO = numel(orders);
stab = struct('r', num2cell(orders(:).'), 'f', [], 'zeta', [], 'isStable', []);
prev = zeros(0, 2);  R = [];  F = [];  Z = [];
for k = 1:nO
    P  = band_poles(esprit_poles(U, M, orders(k)), fs, fBand);
    st = false(size(P,1), 1);
    for i = 1:size(P,1)
        st(i) = any(abs(prev(:,1) - P(i,1))/P(i,1) < tolF & ...
                    abs(prev(:,2) - P(i,2))/P(i,2) < tolZ);
    end
    stab(k).f = P(:,1);  stab(k).zeta = P(:,2);  stab(k).isStable = st;
    R = [R; repmat(orders(k), nnz(st), 1)];  F = [F; P(st,1)];  Z = [Z; P(st,2)];  %#ok<AGROW>
    prev = P;
end
v = zeros(0, 1);  mF = v;  mZ = v;  mLo = v;  mHi = v;  mN = v;
if ~isempty(F)
    [F, o] = sort(F);  R = R(o);  Z = Z(o);
    g = cumsum([true; diff(F)./F(2:end) > tolF]);
    for cc = 1:max(g)
        in = g == cc;  nOrd = numel(unique(R(in)));
        if nOrd >= minFrac*nO
            mF(end+1,1) = median(F(in));   mZ(end+1,1) = 100*median(Z(in));   %#ok<AGROW>
            mLo(end+1,1) = min(F(in));     mHi(end+1,1) = max(F(in));         %#ok<AGROW>
            mN(end+1,1) = nOrd;                                               %#ok<AGROW>
        end
    end
end
modes = table(mF, mZ, mLo, mHi, mN, repmat(nO, numel(mF), 1), 'VariableNames', ...
              {'Freq_Hz', 'Damping_pct', 'Fmin_Hz', 'Fmax_Hz', 'StableOrders', 'OrdersUsed'});
end

function [ne, A0, sg, yhat] = mode_fit(y, fs, f, zetaPct)
n  = (0:numel(y)-1).';  f = f(:);  ze = zetaPct(:)/100;  nm = numel(f);
sg = -ze .* (2*pi*f) ./ sqrt(1 - ze.^2);
z  = exp([sg + 1i*2*pi*f; sg - 1i*2*pi*f] / fs);
V  = z.' .^ n;
c  = pinv(V, 1e-10*norm(V)) * y;
yhat = real(V * c);
e  = zeros(nm, 1);
for k = 1:nm
    e(k) = sum((2*real(c(k) * z(k).^n)).^2);
end
ne = e / max([e; eps]);
A0 = 2*abs(c(1:nm));
end

function [fm, zm] = match_modes(fRef, f, zeta, relTol)
nR = numel(fRef);  fm = nan(1, nR);  zm = nan(1, nR);
if isempty(f) || nR == 0, return; end
D = abs(f(:).' - fRef(:)) ./ fRef(:);
D(D >= relTol) = Inf;
for it = 1:min(nR, numel(f))
    [v, ix] = min(D(:));
    if ~isfinite(v), break; end
    [ri, ci] = ind2sub(size(D), ix);
    fm(ri) = f(ci);  zm(ri) = zeta(ci);
    D(ri,:) = Inf;  D(:,ci) = Inf;
end
end
