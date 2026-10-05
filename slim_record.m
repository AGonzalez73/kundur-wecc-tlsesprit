function slim_record(srcFile, dstFile, kind)
%SLIM_RECORD  Copies the signals used by this repository from a full
%   simulation workspace file to a small .mat file.
%
%   slim_record(srcFile, dstFile, 'small_signal')
%       keeps t1, PB79, DwG3, dwG1, dwG2, dwG4
%   slim_record(srcFile, dstFile, 'fault')
%       keeps t1, DELTAT, dwT, PeT, Vt, PB79
%
%   Only the listed variables are read, so figures, axes and other objects
%   saved in the source file are never loaded. This is how the files in
%   data/ were produced from the workspaces saved after each Simulink run
%   (see data/README.md for the variables and units).
%
%   Example
%     slim_record('K_undur_4.3_fallatrifasica_P.mat', ...
%                 fullfile('data','three_phase_fault','Kundur_Fault_PVcontrolP.mat'), 'fault')

    switch lower(kind)
        case 'small_signal', vars = {'t1', 'PB79', 'DwG3', 'dwG1', 'dwG2', 'dwG4'};
        case 'fault',        vars = {'t1', 'DELTAT', 'dwT', 'PeT', 'Vt', 'PB79'};
        otherwise, error('slim_record:kind', 'kind must be ''small_signal'' or ''fault''.');
    end
    present = who('-file', srcFile);
    missing = setdiff(vars, present);
    if ~isempty(missing)
        error('slim_record:missing', '%s lacks: %s', srcFile, strjoin(missing, ', '));
    end
    S = load(srcFile, vars{:});
    for k = 1:numel(vars)
        S.(vars{k}) = double(S.(vars{k}));
    end
    save(dstFile, '-struct', 'S', '-v7');
    fprintf('%s -> %s (%s)\n', srcFile, dstFile, strjoin(vars, ', '));
end
