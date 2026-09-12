function setup_path(repo_path)
% dlh.setup_path                - set up the path for the repo this file is in
% dlh.setup_path(repo_path)     - ...or for a repo somewhere else
%
% Put AP_histology on the MATLAB path correctly. Use this instead of a bare
% addpath(genpath(...)) - it handles the two things that bite:
%
% 1. The package is split across gui_functions/, utility_functions/ and
%    analysis_functions/ (upstream commit b9f16f0 moved it out of the repo
%    root). A path saved before that only covers the root, and AP_histology
%    then dies at the first utility_functions call - e.g.
%    "Unable to resolve the name 'ap_histology.natsortfiles'".
%    genpath skips '+' folders and returns their parents, which is exactly
%    what package resolution needs, so genpath over the whole repo is right.
%
% 2. custom_functions/compat holds shims for functions that only exist in
%    newer MATLAB (currently hex2rgb, built in from R2024a). Those must be
%    on the path on older MATLAB and OFF it on newer, or they shadow the
%    real thing. This adds compat only when the built-in is missing.
%
% Suggested startup.m line:
%   run('/path/to/AP_histology/custom_functions/+dlh/setup_path.m')
% or, once the repo root is reachable:
%   addpath('/path/to/AP_histology/custom_functions'); dlh.setup_path

arguments
    repo_path {mustBeTextScalar} = ''
end

if isempty(char(repo_path))
    % .../AP_histology/custom_functions/+dlh/setup_path.m -> repo root
    repo_path = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
repo_path = char(repo_path);

if ~exist(fullfile(repo_path,'AP_histology.m'),'file')
    error('dlh:notRepo','No AP_histology.m in %s',repo_path);
end

compat_path = fullfile(repo_path,'custom_functions','compat');

addpath(genpath(repo_path));

% --- Drop the compat shims if MATLAB provides the real functions ---------
shimmed = dir(fullfile(compat_path,'*.m'));
needed = false;

for curr_shim = 1:numel(shimmed)
    [~,fcn_name] = fileparts(shimmed(curr_shim).name);
    found = which(fcn_name,'-all');
    % Anything outside compat/ means MATLAB has its own - shim not needed
    real_impl = found(~contains(found,compat_path));
    if isempty(real_impl)
        needed = true;
    end
end

if ~needed && ~isempty(shimmed)
    rmpath(compat_path);
end

rehash toolboxcache

fprintf('AP_histology path set from %s\n',repo_path);
if needed
    fprintf('  compat shims active (%s) - this MATLAB predates them\n', ...
        strjoin(erase({shimmed.name},'.m'),', '));
end

end
