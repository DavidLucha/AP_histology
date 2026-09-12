function contours = atlas_contours(atlas_slice,st,opts)
% contours = dlh.atlas_contours(atlas_slice,st,...)
%
% Turn an aligned CCF label image (in histology pixel coordinates) into
% vector outlines, one entry per structure.
%
% INPUTS
% atlas_slice - 2D label image, values index rows of st (i.e. the
%               annotation_volume_10um_by_index convention)
% st          - structure tree table from ap_histology.load_ccf
%
% NAME-VALUE
% CollapseDepth      - 0 = outline every region as displayed (default).
%                      N > 0 = merge each region into its ancestor at depth
%                      N of the structure tree, e.g. 5-7 gives sensible
%                      figure-level regions, 2-3 gives major divisions.
% SimplifyTolerance  - Douglas-Peucker tolerance passed to reducepoly,
%                      range [0 1], default 0.001. 0 = keep every pixel
%                      step (staircase edges).
% MinRegionArea      - drop connected components smaller than this many
%                      pixels (default 25) - removes single-pixel specks.
% IncludeRegions     - string array of acronyms; if given, only these
%                      structures (and their descendants) are outlined.
%
% OUTPUT
% contours - struct array with fields:
%   .row        row in st
%   .acronym    structure acronym
%   .name       full structure name
%   .color      CCF colour as '#RRGGBB'
%   .boundaries cell array of Nx2 [x y] vertex lists in SVG units
%               (pixel index - 0.5, so they sit on the raster exactly)
%   .is_hole    logical, one per boundary (true = internal hole)

arguments
    atlas_slice
    st table
    opts.CollapseDepth (1,1) double {mustBeNonnegative} = 0
    opts.SimplifyTolerance (1,1) double {mustBeInRange(opts.SimplifyTolerance,0,1)} = 0.001
    opts.MinRegionArea (1,1) double {mustBeNonnegative} = 25
    opts.IncludeRegions string = string.empty
end

contours = struct('row',{},'acronym',{},'name',{},'color',{}, ...
    'boundaries',{},'is_hole',{});

if isempty(atlas_slice)
    return
end

label_im = double(atlas_slice);
n_st = height(st);

% --- Optionally collapse to a coarser level of the structure tree --------
if opts.CollapseDepth > 0
    map = local_collapse_map(st,opts.CollapseDepth);
    valid = label_im >= 1 & label_im <= n_st;
    label_im(valid) = map(label_im(valid));
end

% --- Restrict to named regions (and their descendants) ------------------
if ~isempty(opts.IncludeRegions)
    keep_rows = local_region_family(st,opts.IncludeRegions);
    keep_mask = false(n_st,1);
    keep_mask(keep_rows) = true;
    valid = label_im >= 1 & label_im <= n_st;
    drop = valid;
    drop(valid) = ~keep_mask(label_im(valid));
    label_im(drop) = 0;
end

% --- Group pixels by label (fast: sort once rather than scan per label) --
[vals,ord] = sort(label_im(:));
grp_end = [find(diff(vals)); numel(vals)];
grp_start = [1; grp_end(1:end-1)+1];
uvals = vals(grp_end);

im_size = size(label_im);
acronyms = string(st.acronym);
names = string(st.name);

has_reducepoly = exist('reducepoly','file') == 2 || exist('reducepoly','builtin') == 5;

for curr_grp = 1:numel(uvals)

    curr_label = uvals(curr_grp);

    % Skip background (index 1 is root/outside in the by-index atlas)
    if curr_label <= 1 || curr_label > n_st
        continue
    end
    if strcmpi(acronyms(curr_label),'root')
        continue
    end

    idx = ord(grp_start(curr_grp):grp_end(curr_grp));
    if numel(idx) < opts.MinRegionArea
        continue
    end

    % Build a padded crop containing just this structure (fast boundaries)
    [rr,cc] = ind2sub(im_size,idx);
    r0 = min(rr); c0 = min(cc);
    sub = false(max(rr)-r0+3, max(cc)-c0+3);
    sub(sub2ind(size(sub),rr-r0+2,cc-c0+2)) = true;

    if opts.MinRegionArea > 0
        sub = bwareaopen(sub,opts.MinRegionArea);
        if ~any(sub,'all')
            continue
        end
    end

    [B,~,n_outer] = bwboundaries(sub,8);

    boundaries = {};
    is_hole = false(0,1);

    for curr_b = 1:numel(B)

        % bwboundaries gives [row col]; convert to [x y] in full image
        xy = [B{curr_b}(:,2) + c0 - 2, B{curr_b}(:,1) + r0 - 2];

        if size(xy,1) < 4
            continue
        end

        if opts.SimplifyTolerance > 0 && has_reducepoly
            xy_simple = reducepoly(xy,opts.SimplifyTolerance);
            if size(xy_simple,1) >= 3
                xy = xy_simple;
            end
        end

        % Pixel index -> SVG user units (pixel centre sits at index-0.5)
        boundaries{end+1} = xy - 0.5; %#ok<AGROW>
        is_hole(end+1,1) = curr_b > n_outer; %#ok<AGROW>

    end

    if isempty(boundaries)
        continue
    end

    % (build explicitly - struct() would expand the boundaries cell)
    new_contour = struct;
    new_contour.row = curr_label;
    new_contour.acronym = char(acronyms(curr_label));
    new_contour.name = char(names(curr_label));
    new_contour.color = local_hex(st,curr_label);
    new_contour.boundaries = boundaries;
    new_contour.is_hole = is_hole;

    contours(end+1) = new_contour; %#ok<AGROW>

end

end


function map = local_collapse_map(st,depth)
% Map each structure tree row onto its ancestor at the requested depth
% (rows shallower than that depth map onto themselves)

n = height(st);
map = (1:n)';

path_str = string(st.structure_id_path);
ids = double(st.id);

target_id = nan(n,1);
for curr_row = 1:n
    p = str2double(split(erase(path_str(curr_row),'"'),'/'));
    p = p(~isnan(p));
    if isempty(p)
        continue
    end
    target_id(curr_row) = p(min(numel(p),depth+1));
end

[tf,loc] = ismember(target_id,ids);
map(tf) = loc(tf);

end


function rows = local_region_family(st,acronyms)
% All rows whose structure_id_path contains any of the named structures

ids = double(st.id);
path_str = string(st.structure_id_path);

target_rows = find(ismember(lower(string(st.acronym)),lower(acronyms)));
if isempty(target_rows)
    warning('dlh:unknownRegion','No CCF structures matched: %s', ...
        strjoin(cellstr(acronyms),', '));
    rows = [];
    return
end

rows = [];
for curr_target = target_rows(:)'
    pattern = "/" + string(ids(curr_target)) + "/";
    rows = [rows; find(contains(path_str,pattern))]; %#ok<AGROW>
end
rows = unique([rows; target_rows(:)]);

end


function hex = local_hex(st,row)
% CCF colour as '#RRGGBB'

hex = '#FFFFFF';
if ~ismember('color_hex_triplet',st.Properties.VariableNames)
    return
end
c = st.color_hex_triplet(row);
if iscell(c); c = c{1}; end
c = erase(string(c),'"');
c = char(c);
if numel(c) == 6
    hex = ['#' c];
elseif numel(c) < 6 && ~isempty(c)
    hex = ['#' repmat('0',1,6-numel(c)) c];
end

end
