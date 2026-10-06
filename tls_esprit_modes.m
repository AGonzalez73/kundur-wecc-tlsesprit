%% =====================================================================
%  TLS-ESPRIT identification of electromechanical modes (ringdown)
%  Supplementary code -- IEEE Latin America Transactions
%  ---------------------------------------------------------------------
%  USAGE  Load one scenario into the workspace, set caseName below and
%         run, e.g.   load(fullfile('data','Kundur_PVcontrolP.mat'))
%                     tls_esprit_modes
%         The script reads t1, PB79 and DwG3 from the workspace, prints a
%         summary, draws one figure and writes results/<caseName>/
%         (summary.txt and one table of modes per signal).
%         run_all.m runs the four scenarios and presets caseName, doNoise
%         and makePlots through the struct runOpts.
%         MATLAB R2018b or later, no toolboxes. Deterministic (fixed seed).
%
%  REFERENCES
%   [1] NERC, "Recommended Oscillation Analysis for Monitoring and
%       Mitigation Reference Document," Technical Reference Document,
%       Nov. 2021.
%   [2] R. Roy, T. Kailath, "ESPRIT - estimation of signal parameters via
%       rotational invariance techniques," IEEE Trans. Acoust., Speech,
%       Signal Process., vol. 37, no. 7, pp. 984-995, 1989.
%       doi:10.1109/29.32276
%   [3] P. Tripathy, S. C. Srivastava, S. N. Singh, "A modified TLS-ESPRIT-
%       based method for low-frequency mode identification in power
%       systems utilizing synchrophasor measurements," IEEE Trans. Power
%       Syst., vol. 26, no. 2, pp. 719-727, 2011.
%       doi:10.1109/TPWRS.2010.2055901
%   [4] M. Sahoo, S. Rai, "An improved TLS-ESPRIT-based mode identification
%       technique for low-frequency oscillations in power system using
%       synchrophasor measurements," Electrical Engineering, vol. 107,
%       no. 4, pp. 4103-4123, 2025. doi:10.1007/s00202-024-02751-8
%   [5] Y. Hua, T. K. Sarkar, "Matrix pencil method for estimating
%       parameters of exponentially damped/undamped sinusoids in noise,"
%       IEEE Trans. Acoust., Speech, Signal Process., vol. 38, no. 5,
%       pp. 814-824, 1990. doi:10.1109/29.56027
%   [6] R. Kuiava, E. Z. dos Passos, G. H. da C. Oliveira, R. Schumacher,
%       "Separating low-frequency electromechanical modes from spurious
%       modes in ambient data analysis by means of modal stabilization
%       diagrams," Electr. Power Syst. Res., vol. 201, 107502, 2021.
%       doi:10.1016/j.epsr.2021.107502
%   [7] M. He, P. Liang, J. Liu, Z. Liang, "Review and comparison of
%       methods and benchmarks for automatic modal identification based on
%       stabilization diagram," J. Traffic Transp. Eng. (Engl. Ed.),
%       vol. 11, no. 2, pp. 209-224, 2024. doi:10.1016/j.jtte.2023.05.007
%   [8] E.-H. Djermoune, M. Tomczak, "Perturbation analysis of subspace-
%       based methods in estimating a damped complex exponential," IEEE
%       Trans. Signal Process., vol. 57, no. 11, pp. 4558-4563, 2009.
%   [9] MathWorks, "modalsd - Generate stabilization diagram for modal
%       analysis," Signal Processing Toolbox documentation; default
%       SCriteria = [0.01 0.05]. (Only its criteria are used here.)
%  [10] J. Follum, F. Tuffner, L. Dosiek, J. Pierre, "Power system
%       oscillatory behaviors: sources, characteristics, & analyses,"
%       PNNL-26375 / NASPI-2017-TR-003, May 2017.
% =====================================================================
if ~exist('runOpts', 'var'), clc; close all; end   % batch runs keep the console

%% ---------------- Settings (basis in the header) --------------------
caseName = 'P-control';     % label of the loaded scenario
timeVar  = 't1';            % time vector in the workspace

% workspace variable, mode reported, range where it is sought [Hz], tSkip [s]
sigSpec = { 'PB79', 'Inter-area',   [0.1 1.0], 0.5
            'DwG3', 'Local Area 2', [1.0 2.0], 0.1 };

tDist = 150;   tPulse = 0.1;        % Vref pulse: 150.0-150.1 s       [1]
fSlow = 0.62;  nCyc   = 4;          % Tw = nCyc/fSlow = 6.45 s        [1]
decim = 1;                          % 1: 60 Hz output; 3: 20 Hz       [1]

detrendMode = 'linear';             % offset y0 and drift removed     [4]
fBand       = [0.1 2.0];            % electromechanical band [Hz]     [1]
rStab       = 2:60;                 % model orders scanned            [6]
tolF        = 0.01;                 % stable pole: df/f < 1 %         [9]
tolZ        = 0.05;                 % stable pole: dzeta/zeta < 5 %   [9]
minFrac     = 0.30;                 % mode: stable in >= 30 % of orders
neDominant  = 0.10;                 % dominant mode: NE >= 0.10       [4]
matchTol    = 0.05;                 % same mode: |df|/f < 5 %

doSweep = true;   dT0Set = 0:0.1:0.5;   TwSet = (3:0.25:4)/fSlow;  %  [1]
doNoise = true;   snrSet = [40 30 20];  nMC = 200;  rngSeed = 0;   %  [4]
makePlots = true;

% Presets from run_all.m (absent in interactive use)
if exist('runOpts', 'var')
    caseName = runOpts.caseName;  doNoise = runOpts.doNoise;  makePlots = runOpts.makePlots;
end

%% ---------------- Read the data from the workspace ------------------
for v = [{timeVar}, sigSpec(:,1).']
    if ~exist(v{1}, 'var')
        error('Variable "%s" not found in the workspace. Load the scenario first.', v{1});
    end
end
tAll = double(eval(timeVar));  tAll = tAll(:);
nSig = size(sigSpec, 1);
Yall = cell(1, nSig);
for q = 1:nSig
    Yall{q} = double(eval(sigSpec{q,1}));  Yall{q} = Yall{q}(:);
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

%% ---------------- Steps 1-4: identification per signal --------------
res = struct([]);
for q = 1:nSig
    [tq, yq, fs] = get_window(tAll, Yall{q}, t0v(q), t0v(q) + Tw);
    yd = detrend_local(yq, detrendMode);
    N  = numel(yd);  M = floor(N/2);
    U  = hankel_svd(yd, M);

    % Step 3: physical modes from the stabilization diagram
    [md, stab] = stabilization(U, M, fs, rStab, fBand, tolF, tolZ, minFrac);
    if height(md) == 0
        warning('%s: no stable mode in %.1f-%.1f Hz; skipped.', sigSpec{q,1}, fBand);
        continue;
    end

    % Step 4: energy of each mode from a fit of the modes of step 3
    [md.NE, A0, sg, yhat] = mode_fit(yd, fs, md.Freq_Hz, md.Damping_pct);
    md.Dominant = md.NE >= neDominant;
    rg  = sigSpec{q,3};
    inR = find(md.Freq_Hz >= rg(1) & md.Freq_Hz < rg(2) & md.NE > 0);
    iT  = [];
    if ~isempty(inR), [~, b] = max(md.NE(inR)); iT = inR(b); end

    % Window check: time for the reported mode to decay to the rms of the
    % record before the event (no flat content in the window [1]). That
    % record ends 1 s before the event, out of reach of the zero-phase
    % filter used when decim > 1.
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
    res(j).det = nan(size(snrSet));  res(j).zNoise = nan(numel(snrSet), 2);
end
if isempty(res), error('No signal produced a stable mode.'); end

%% ---------------- Step 5: window sweep and noise test ---------------
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

    % Noise test [4]: white noise at each SNR (relative to the rms of the
    % detrended window), steps 2-3 repeated; the reported mode must be
    % found again
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

%% ---------------- Summary -------------------------------------------
S = {sprintf('Case: %s   fs = %.0f Hz   Tw = %.2f s   %d windows in the sweep', ...
             caseName, res(1).fs, Tw, numel(dT0Set)*numel(TwSet)*doSweep), ''};
for q = 1:numel(res)
    R = res(q);  m = R.modes;
    S{end+1} = sprintf('%s -> %s   window [%.3f, %.3f] s', R.name, R.label, R.t0, R.t0 + Tw);
    if isempty(R.iT)
        S{end+1} = sprintf('   no mode with energy in %.1f-%.1f Hz', R.range);
    else
        k = R.iT;
        S{end+1} = sprintf('   f = %.4f Hz [%.4f-%.4f]   zeta = %.2f %% [%.2f-%.2f]', ...
            m.Freq_Hz(k), m.FminWin_Hz(k), m.FmaxWin_Hz(k), ...
            m.Damping_pct(k), m.ZminWin_pct(k), m.ZmaxWin_pct(k));
        S{end+1} = sprintf('   NE = %.2f   stable in %d of %d orders   found in %d of %d windows', ...
            m.NE(k), m.StableOrders(k), m.OrdersUsed(k), m.WinFound(k), R.nWin);
        S{end+1} = sprintf('   fit of the %d mode(s) found: %.1f %%', height(m), R.fit);
        if doNoise
            for u = 1:numel(snrSet)
                S{end+1} = sprintf('   noise %2.0f dB: found in %5.1f %% of %d runs, zeta 5-95 %%: %.2f-%.2f', ...
                    snrSet(u), R.det(u), nMC, R.zNoise(u,1), R.zNoise(u,2));
            end
        end
        if ~isnan(R.Tdn)
            S{end+1} = sprintf('   decays to the pre-event noise floor (%.2g rms) %.1f s after the window start', ...
                R.sN, R.Tdn);
        end
    end
    isT = false(height(m), 1);  isT(R.iT) = true;
    oth = find(m.Dominant & ~isT);
    if ~isempty(oth)
        txt = arrayfun(@(k) sprintf('%.4f Hz %.2f %% (NE %.2f)', m.Freq_Hz(k), m.Damping_pct(k), ...
                       m.NE(k)), oth, 'UniformOutput', false);
        S{end+1} = ['   other dominant modes: ' strjoin(txt(:).', ';  ')];
    end
    S{end+1} = '';
end
S{end+1} = 'Same eigenvalue in the other signal:';
for q = 1:numel(res)
    if isempty(res(q).iT), continue; end
    k = res(q).iT;  fT = res(q).modes.Freq_Hz(k);
    for p = setdiff(1:numel(res), q)
        mp = res(p).modes;  d = abs(mp.Freq_Hz - fT)/fT;  d(~mp.Dominant) = Inf;
        [d, jm] = min(d);
        if d < matchTol
            S{end+1} = sprintf('   %s %s %.4f Hz %.2f %%  |  %s %.4f Hz %.2f %% [%.2f-%.2f]', ...
                res(q).label, res(q).name, fT, res(q).modes.Damping_pct(k), res(p).name, ...
                mp.Freq_Hz(jm), mp.Damping_pct(jm), mp.ZminWin_pct(jm), mp.ZmaxWin_pct(jm));
        else
            S{end+1} = sprintf('   %s %s %.4f Hz  |  %s: not dominant there', res(q).label, ...
                res(q).name, fT, res(p).name);
        end
    end
end
fprintf('\n');  fprintf('%s\n', S{:});

%% ---------------- Save ----------------------------------------------
outDir = fullfile('results', caseName);
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
fprintf('Results written to %s\n', outDir);

%% ---------------- Figure --------------------------------------------
if makePlots
    figure('Name', ['TLS-ESPRIT  ' caseName], 'Color', 'w');
    nR = numel(res);
    for q = 1:nR
        R = res(q);  m = R.modes;
        ax = subplot(2, nR, q);  hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');
        plot(ax, R.t, R.yd, 'k', R.t, R.yhat, 'r--');
        xlabel(ax, 'Time [s]');  ylabel(ax, [R.name ' (detrended)']);
        title(ax, sprintf('%s: window and fit of the %d mode(s) found (%.1f %%)', R.name, height(m), R.fit));
        legend(ax, {'Simulated', 'Modes found'}, 'Location', 'best');
        ax = subplot(2, nR, nR + q);  hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');
        for k = 1:numel(R.stab)
            st = R.stab(k).isStable;
            plot(ax, R.stab(k).f(~st), R.stab(k).r*ones(nnz(~st),1), 'o', 'Color', [.7 .7 .7], 'MarkerSize', 3);
            plot(ax, R.stab(k).f(st),  R.stab(k).r*ones(nnz(st),1),  'b+', 'MarkerSize', 5);
        end
        for k = find(m.Dominant).'
            plot(ax, m.Freq_Hz(k)*[1 1], rStab([1 end]), '--', 'Color', [.5 .5 .5]);
        end
        if ~isempty(R.iT)
            plot(ax, m.Freq_Hz(R.iT)*[1 1], rStab([1 end]), 'r-', 'LineWidth', 1.5);
        end
        xlim(ax, fBand);  ylim(ax, rStab([1 end]));
        xlabel(ax, 'Frequency [Hz]');  ylabel(ax, 'Model order');
        title(ax, sprintf('%s: stabilization diagram (+ stable); red: %s', R.name, R.label));
    end
end

%% =====================================================================
%  Local functions
%% =====================================================================
function [t, y, fs] = get_window(tAll, yAll, ta, tb)
%GET_WINDOW  Samples in [ta, tb]; repeated time stamps keep the last value.
    idx = tAll >= ta - 1e-9 & tAll <= tb + 1e-9;
    [t, iu] = unique(tAll(idx), 'last');  y = yAll(idx);  y = y(iu);
    dt = diff(t);
    if numel(t) < 20 || max(abs(dt - mean(dt)))/mean(dt) > 1e-6
        error('Window [%.2f, %.2f] s: too short or not uniformly sampled.', ta, tb);
    end
    fs = 1/mean(dt);
end

function [t, Y] = decimate_zp(t, Y, q)
%DECIMATE_ZP  Anti-alias filter and down-sampling by q [1]: Hamming-windowed
%   sinc FIR (16q+1 taps, cutoff at 0.8 of the new Nyquist frequency), run
%   forward and backward over the whole record (zero phase); no toolbox.
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
%DETREND_LOCAL  Mean ('constant') or mean and slope ('linear') removed by
%   least squares.
    N = numel(y);
    switch lower(mode)
        case 'constant', A = ones(N,1);
        case 'linear',   A = [ones(N,1), (0:N-1).'];
        otherwise, error('Unknown detrend mode: %s', mode);
    end
    yd = y - A*(A\y);
end

function U = hankel_svd(yd, M)
%HANKEL_SVD  Left singular vectors of the M-row Hankel matrix of yd. The
%   unit-variance scaling improves conditioning and leaves U unchanged.
    yn = yd / std(yd);
    [U, ~, ~] = svd(hankel(yn(1:M), yn(M:end)), 'econ');
end

function z = esprit_poles(U, M, r)
%ESPRIT_POLES  Discrete-time poles by TLS-ESPRIT [2]: with Us = U(:,1:r),
%   [Us(1:M-1,:) Us(2:M,:)] = W*S*F', Psi = -F12/F22, z = eig(Psi).
%   The TLS step needs 2r <= M-1, so r is capped at floor((M-1)/2).
    r  = min(r, floor((M-1)/2));
    Us = U(:, 1:r);
    [~, ~, F] = svd([Us(1:M-1,:), Us(2:M,:)], 'econ');
    z = eig(-F(1:r, r+1:end) / F(r+1:end, r+1:end));
    z = z(abs(z) > 1e-12);
end

function P = band_poles(z, fs, fBand)
%BAND_POLES  [f zeta] of the poles inside fBand with positive damping.
    s = log(z(:))*fs;  f = imag(s)/(2*pi);  ze = -real(s)./abs(s);
    k = f >= fBand(1) & f <= fBand(2) & ze > 0;
    P = [f(k), ze(k)];
    if isempty(P), P = zeros(0, 2); return; end   % sortrows fails on empty input
    P = sortrows(P, 1);
end

function [modes, stab] = stabilization(U, M, fs, orders, fBand, tolF, tolZ, minFrac)
%STABILIZATION  Stabilization diagram [6], [9]. A pole of order r is
%   stable when a pole of order r-1 is within tolF in f and tolZ in zeta.
%   Stable poles are grouped by frequency (consecutive gaps < tolF); a
%   group stable in >= minFrac of the orders is a mode, reported by the
%   medians of its poles [7]. Orders above floor((M-1)/2) are skipped:
%   the TLS step cannot use them and they would repeat the same poles.
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
%MODE_FIT  Least-squares amplitudes of the modes found by the
%   stabilization diagram: y(n) = sum_k 2*Re(c_k z_k^n), with
%   z_k = exp(s_k/fs), s_k = sg_k + j*2*pi*f_k and sg_k = -zeta_k*wn_k,
%   wn_k = 2*pi*f_k/sqrt(1 - zeta_k^2). The pseudo-energy of mode k over
%   the window, sum((2*Re(c_k z_k^n)).^2) [10], is normalized by the
%   largest (NE [4]); A0 = 2|c_k| is the amplitude of the mode at the
%   window start. The rank tolerance guards against two close modes.
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
%MATCH_MODES  One-to-one assignment of estimated modes to reference modes,
%   closest relative frequency first, within relTol.
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