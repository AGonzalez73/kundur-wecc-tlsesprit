function simulate_cases(names)
%SIMULATE_CASES  Regenerates the records in data/ with the Simulink models.
%   simulate_cases                                   all records
%   simulate_cases({'sync_fault9', 'pv_p_fault9'})   selected records
%   Record names: <scenario>_<event>, scenario = sync, pv_p, pv_q or pv_v,
%   event = pulse, fault12 or fault9 (fault<N>: cleared after N cycles).

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'models'));
if nargin == 0
    sc = {'sync', 'pv_p', 'pv_q', 'pv_v'};
    ev = {'pulse', 'fault12', 'fault9'};
    [i, j] = ndgrid(1:numel(sc), 1:numel(ev));
    names = strcat(sc(i(:)), '_', ev(j(:)));
end
names = cellstr(names);

for k = 1:numel(names)
    fprintf('Simulating %s (%d of %d)\n', names{k}, k, numel(names));
    out = sim(case_input(names{k}));
    save_record(out, fullfile(root, 'data', [names{k} '.mat']), strncmp(names{k}, 'pv', 2));
end
end

function in = case_input(name)
p = strsplit(name, '_');
event = p{end};
if strcmp(p{1}, 'sync')
    mdl = 'kundur_sync';
else
    mdl = 'kundur_pv';
end
load_system(mdl);
in = Simulink.SimulationInput(mdl);
if strcmp(event, 'pulse')
    in = in.setVariable('k_pulse', 1);
    in = in.setVariable('k_fault', 1000);
else
    cyc = sscanf(event, 'fault%d');
    in = in.setVariable('k_pulse', 1000);
    in = in.setVariable('k_fault', 1);
    in = in.setBlockParameter([mdl '/Fault'], 'SwitchTimes', sprintf('[150 150+%d/60]*k_fault', cyc));
end
if strcmp(p{1}, 'pv')
    v = pv_mode(upper(p{2}));
    f = fieldnames(v);
    for n = 1:numel(f)
        in = in.setVariable(f{n}, v.(f{n}));
    end
end
end

function v = pv_mode(mode)
P0 = 699.9091762902/900;
Q0 = 131.6410273073/900;
V0 = 0.9805390732;
v.QVControl    = 0;
v.FrqControl   = 0;
v.PlantControl = 1;
v.PQPriority   = 0;
v.QControl     = double(mode == 'Q');
v.PFControl    = double(mode == 'P');
v.Pref_pl      = P0;
v.Qref_pl      = Q0;
v.Vref_pl      = V0;
v.pfaref0      = atan2(Q0, P0*V0);
end

function save_record(out, file, isPV)
vars = {'t1', 'PB79', 'DwG3', 'dwT', 'dthetaT', 'VB79'};
if isPV
    vars = [vars, {'PB5', 'PB5Q', 'V5'}];
else
    vars = [vars, {'PB2', 'QB2'}];
end
S = struct();
for k = 1:numel(vars)
    x = out.get(vars{k});
    if isa(x, 'timeseries'), x = x.Data; end
    if isstruct(x), x = x.signals.values; end
    if ndims(x) == 3, x = reshape(permute(x, [3 2 1]), size(x, 3), []); end
    S.(vars{k}) = double(x);
end
save(file, '-struct', 'S', '-v7');
end
