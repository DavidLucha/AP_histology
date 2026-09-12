function clean_tiffs(folder_path, make_backup, opts)
% clean_tiffs(folder_path, make_backup, ...)
%
% Fix OME-TIFFs whose MATLAB-visible directory count doesn't match the
% channel count declared in their OME XML (zero-size directories, or extra
% directories beyond SizeC), which makes tiffreadVolume return mismatched
% dimensions.
%
% Files that are already correct are SKIPPED - nothing is read or
% rewritten - so calling this repeatedly (as AP_histology does on every
% "Load images") is cheap after the first pass.
%
% INPUTS
% folder_path  - folder of .tif/.tiff files
% make_backup  - copy originals into _histology_backups before the first
%                rewrite of each file (default true)
%
% NAME-VALUE
% Force        - re-check every file even if the cache says it's clean,
%                and rewrite even if it looks correct (default false)
% Compression  - TIFF compression for rewritten files: 'lzw' (default),
%                'none', 'packbits', 'deflate'. All lossless. 'none'
%                reproduces the original behaviour.
% Verbose      - per-file detail (default false; a one-line summary is
%                always printed)
%
% Two levels of skipping:
%   1. Cache  - .clean_tiffs.json in the folder records name/size/mtime of
%               files known to be clean. Matching files are skipped without
%               even calling imfinfo. Delete the file, or pass Force, to
%               re-check from scratch.
%   2. Structure - if imfinfo shows exactly SizeC directories and all are
%               valid, the file is already clean and is left alone.
%
% Level 2 is authoritative - the cache is only a shortcut past imfinfo, and
% any file whose size or timestamp changed is re-checked properly.

arguments
    folder_path {mustBeTextScalar}
    make_backup (1,1) logical = true
    opts.Force (1,1) logical = false
    opts.Compression {mustBeMember(opts.Compression, ...
        {'none','lzw','packbits','deflate'})} = 'lzw'
    opts.Verbose (1,1) logical = false
end

folder_path = char(folder_path);
if ~exist(folder_path,'dir')
    error('clean_tiffs:noFolder','Folder not found: %s',folder_path);
end

t_start = tic;

% Clear any temp files left behind by an interrupted run
% (these match AP_histology's *.tif* pattern and would load as extra slices)
stale_tmp = dir(fullfile(folder_path,'*.tmp.tif'));
for curr_stale = 1:numel(stale_tmp)
    delete(fullfile(stale_tmp(curr_stale).folder,stale_tmp(curr_stale).name));
end

files = [dir(fullfile(folder_path,'*.tif')); ...
         dir(fullfile(folder_path,'*.tiff'))];
files = files(~[files.isdir]);

if isempty(files)
    fprintf('clean_tiffs: no TIFFs in %s\n',folder_path);
    return
end

% ---- Cache of files already known to be clean --------------------------
cache_file = fullfile(folder_path,'.clean_tiffs.json');
cache = local_read_cache(cache_file,opts.Force);

backup_dir = fullfile(folder_path,'_histology_backups');

n_cached = 0;
n_already = 0;
n_cleaned = 0;
n_skipped = 0;

for curr_file = 1:numel(files)

    in_file = fullfile(files(curr_file).folder,files(curr_file).name);

    % --- Level 1: cache hit, no imfinfo needed -------------------------
    if ~opts.Force && local_cache_hit(cache,files(curr_file))
        n_cached = n_cached + 1;
        if opts.Verbose
            fprintf('  %s: unchanged since last clean, skipping\n',files(curr_file).name);
        end
        continue
    end

    if opts.Verbose
        fprintf('\nChecking: %s\n',in_file);
    end

    try
        info = imfinfo(in_file);
    catch ME
        warning('clean_tiffs:badFile','Could not read %s (%s)', ...
            files(curr_file).name,ME.message);
        n_skipped = n_skipped + 1;
        continue
    end

    % --- OME XML -------------------------------------------------------
    ome_xml = '';
    if isfield(info(1),'ImageDescription') && ~isempty(info(1).ImageDescription)
        ome_xml = info(1).ImageDescription;
    elseif isfield(info(1),'Description') && ~isempty(info(1).Description)
        ome_xml = info(1).Description;
    end

    declared_c = local_ome_num(ome_xml,'SizeC');

    if isnan(declared_c) || declared_c < 1
        warning('clean_tiffs:noSizeC', ...
            'Could not read SizeC from OME XML, skipping: %s',files(curr_file).name);
        n_skipped = n_skipped + 1;
        continue
    end

    % Keeping the first SizeC planes is only safe for a single Z/T plane
    size_z = local_ome_num(ome_xml,'SizeZ');
    size_t = local_ome_num(ome_xml,'SizeT');
    if (~isnan(size_z) && size_z > 1) || (~isnan(size_t) && size_t > 1)
        warning('clean_tiffs:multidim', ...
            ['%s declares SizeZ=%g, SizeT=%g - keeping only the first %d ' ...
            'planes would discard data. Skipping.'], ...
            files(curr_file).name,size_z,size_t,declared_c);
        n_skipped = n_skipped + 1;
        continue
    end

    % --- Directory census ----------------------------------------------
    valid_idx = find(arrayfun(@(s) ...
        isfield(s,'Width') && isfield(s,'Height') && ...
        ~isempty(s.Width) && ~isempty(s.Height) && ...
        s.Width > 0 && s.Height > 0, info));

    total_dirs = numel(info);
    n_valid = numel(valid_idx);

    if opts.Verbose
        fprintf('  Directories: %d total, %d valid, %d invalid\n', ...
            total_dirs,n_valid,total_dirs-n_valid);
        fprintf('  OME SizeC: %d (extra valid: %d)\n', ...
            declared_c,max(0,n_valid-declared_c));
    end

    if n_valid < declared_c
        warning('clean_tiffs:tooFewDirs', ...
            'Only %d valid directories but SizeC=%d in %s - skipping', ...
            n_valid,declared_c,files(curr_file).name);
        n_skipped = n_skipped + 1;
        continue
    end

    % --- Level 2: already correct, nothing to do -----------------------
    if ~opts.Force && total_dirs == declared_c && n_valid == declared_c
        n_already = n_already + 1;
        if opts.Verbose
            fprintf('  Already clean.\n');
        end
        cache = local_cache_update(cache,files(curr_file));
        continue
    end

    % --- Rewrite --------------------------------------------------------
    if make_backup
        if ~exist(backup_dir,'dir')
            mkdir(backup_dir);
        end
        backup_file = fullfile(backup_dir,[files(curr_file).name '.bak']);
        if ~exist(backup_file,'file')
            copyfile(in_file,backup_file);
            if opts.Verbose
                fprintf('  Backup created: %s\n',backup_file);
            end
        elseif opts.Verbose
            fprintf('  Backup already exists.\n');
        end
    end

    keep_idx = valid_idx(1:declared_c);

    % Write outside the image folder so a crash can't leave a file that
    % AP_histology would pick up as an extra slice
    tmp_file = [tempname '.tif'];

    try
        for k = 1:numel(keep_idx)
            img = imread(in_file,keep_idx(k),'Info',info);
            if k == 1
                write_args = {'WriteMode','overwrite','Compression',opts.Compression};
                if ~isempty(ome_xml)
                    write_args = [write_args,{'Description',ome_xml}]; %#ok<AGROW>
                end
                imwrite(img,tmp_file,'tif',write_args{:});
            else
                imwrite(img,tmp_file,'tif', ...
                    'WriteMode','append','Compression',opts.Compression);
            end
        end
        movefile(tmp_file,in_file,'f');
    catch ME
        if exist(tmp_file,'file')
            delete(tmp_file);
        end
        warning('clean_tiffs:writeFailed', ...
            'Failed to rewrite %s (%s) - original left untouched', ...
            files(curr_file).name,ME.message);
        n_skipped = n_skipped + 1;
        continue
    end

    n_cleaned = n_cleaned + 1;
    if opts.Verbose
        fprintf('  Cleaned and replaced original.\n');
    end

    % Re-stat so the cache records the file as it is now
    cache = local_cache_update(cache,dir(in_file));

end

local_write_cache(cache_file,cache);

fprintf(['clean_tiffs: %d file(s) in %.1fs - %d cleaned, %d already clean, ' ...
    '%d cached, %d skipped\n'], ...
    numel(files),toc(t_start),n_cleaned,n_already,n_cached,n_skipped);

end


% =======================================================================

function v = local_ome_num(ome_xml,attribute)
% Read a numeric attribute (SizeC, SizeZ, SizeT...) out of the OME XML

v = NaN;
if isempty(ome_xml)
    return
end
tok = regexp(ome_xml,[attribute '="(\d+)"'],'tokens','once');
if ~isempty(tok)
    v = str2double(tok{1});
end

end


function cache = local_read_cache(cache_file,force)

cache = struct('name',{},'bytes',{},'datenum',{});

if force || ~exist(cache_file,'file')
    return
end

try
    raw = jsondecode(fileread(cache_file));
    if isstruct(raw) && all(isfield(raw,{'name','bytes','datenum'}))
        cache = raw(:)';
    end
catch
    % Unreadable cache is not an error - just re-check everything
end

end


function tf = local_cache_hit(cache,file_entry)

tf = false;
if isempty(cache)
    return
end

idx = find(strcmp({cache.name},file_entry.name),1);
if isempty(idx)
    return
end

% Same size and same mtime (to ~0.1 s) means untouched since last clean
tf = cache(idx).bytes == file_entry.bytes && ...
    abs(cache(idx).datenum - file_entry.datenum) < 1.2e-6;

end


function cache = local_cache_update(cache,file_entry)

if isempty(file_entry)
    return
end
file_entry = file_entry(1);

entry = struct('name',file_entry.name, ...
    'bytes',file_entry.bytes,'datenum',file_entry.datenum);

if isempty(cache)
    cache = entry;
    return
end

idx = find(strcmp({cache.name},file_entry.name),1);
if isempty(idx)
    cache(end+1) = entry;
else
    cache(idx) = entry;
end

end


function local_write_cache(cache_file,cache)

try
    fid = fopen(cache_file,'w');
    if fid == -1
        return
    end
    fprintf(fid,'%s',jsonencode(cache,'PrettyPrint',true));
    fclose(fid);
catch
    % Read-only folder etc - the structural check still works, just slower
end

end
