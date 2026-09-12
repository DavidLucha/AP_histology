function files = export_slices(histology_gui,opts)
% files = dlh.export_slices(histology_gui,...)
%
% Export publication-ready versions of the current AP_histology view:
% a full-resolution raster of the histology with the current colour
% settings, and a matching SVG of the CCF boundaries + annotations as real
% vectors. No screenshots involved.
%
% Everything is written at the native pixel size of the (rigid-transformed)
% histology image, and the SVG viewBox matches, so the two layers align
% exactly when combined in Illustrator/Inkscape.
%
% NAME-VALUE
% Slices                - slice numbers to export ([] = current slice)
% OutputDir             - output folder (default <image_path>/figure_export)
% Prefix                - filename prefix (default: image folder name)
% RasterFormat          - 'png' (default) or 'tif'
% WriteChannelStack     - raw per-channel TIFF stack for Fiji, full bit
%                         depth, no colour limits applied (default true)
% ChannelStackCompression - 'lzw' (default), 'none', 'packbits', 'deflate'
% ImageJHeader          - ImageJ hyperstack metadata in the stack so Fiji
%                         opens it as a composite (default true)
% WriteCleanRaster      - histology only, no overlay (default true)
% WriteOverlayRaster    - histology with overlay burned in (default false)
% WriteVectorSVG        - transparent-background SVG overlay (default true)
% WriteCombinedSVG      - SVG with the histology embedded (default true)
% IncludeAtlas          - include CCF boundaries (default true)
% IncludeAnnotations    - include annotations (default true)
% CollapseDepth         - CCF structure tree depth, 0 = as displayed
% SimplifyTolerance     - reducepoly tolerance [0 1], default 0.001
% MinRegionArea         - drop regions below this many px, default 25
% IncludeRegions        - only outline these acronyms (default: all)
% AtlasStroke / AtlasStrokeWidth / AtlasFillOpacity
% AnnotationStroke / AnnotationStrokeWidth / ShowLabels / LabelFontSize
%                       - passed through to dlh.write_svg
%
% OUTPUT
% files - cellstr of everything written

arguments
    histology_gui matlab.ui.Figure
    opts.Slices double = []
    opts.OutputDir {mustBeTextScalar} = ''
    opts.Prefix {mustBeTextScalar} = ''
    opts.RasterFormat {mustBeMember(opts.RasterFormat,{'png','tif'})} = 'png'
    opts.WriteChannelStack (1,1) logical = true
    opts.ChannelStackCompression {mustBeMember(opts.ChannelStackCompression, ...
        {'none','lzw','packbits','deflate'})} = 'lzw'
    opts.ImageJHeader (1,1) logical = true
    opts.WriteCleanRaster (1,1) logical = true
    opts.WriteOverlayRaster (1,1) logical = false
    opts.WriteVectorSVG (1,1) logical = true
    opts.WriteCombinedSVG (1,1) logical = true
    opts.IncludeAtlas (1,1) logical = true
    opts.IncludeAnnotations (1,1) logical = true
    opts.CollapseDepth (1,1) double = 0
    opts.SimplifyTolerance (1,1) double = 0.001
    opts.MinRegionArea (1,1) double = 25
    opts.IncludeRegions string = string.empty
    opts.AtlasStroke {mustBeTextScalar} = '#FFFFFF'
    opts.AtlasStrokeWidth (1,1) double = 2
    opts.AtlasFillOpacity (1,1) double = 0
    opts.AnnotationStroke {mustBeTextScalar} = '#FFFF00'
    opts.AnnotationStrokeWidth (1,1) double = 3
    opts.ShowLabels (1,1) logical = true
    opts.LabelFontSize (1,1) double = 0
end

files = {};

gui_data = guidata(histology_gui);
if ~isfield(gui_data,'data') || isempty(gui_data.data)
    error('dlh:noImages','No images loaded in AP_histology');
end

% ---- Resolve slices, output folder, prefix -----------------------------
slices = opts.Slices;
if isempty(slices)
    slices = gui_data.curr_slice;
end
slices = unique(round(slices(:)'));
slices(slices < 1 | slices > length(gui_data.data)) = [];
if isempty(slices)
    error('dlh:noSlices','No valid slices requested');
end

output_dir = char(opts.OutputDir);
if isempty(output_dir)
    output_dir = fullfile(gui_data.image_path,'figure_export');
end
if ~exist(output_dir,'dir')
    mkdir(output_dir);
end

prefix = char(opts.Prefix);
if isempty(prefix)
    [~,prefix] = fileparts(gui_data.image_path);
end
if isempty(prefix)
    prefix = 'histology';
end

% ---- Structure tree (needed to name/colour CCF regions) ----------------
st = [];
if opts.IncludeAtlas
    if isfield(gui_data,'st') && ~isempty(gui_data.st)
        st = gui_data.st;
    else
        warning('dlh:noStructureTree', ...
            ['Structure tree not loaded - load the aligned atlas first ' ...
            '(Atlas menu) if you want CCF boundaries. Skipping atlas.']);
    end
end
include_atlas = opts.IncludeAtlas && ~isempty(st);

% ---- Export ------------------------------------------------------------
need_vectors = opts.WriteVectorSVG || opts.WriteCombinedSVG;
need_clean = opts.WriteCleanRaster || opts.WriteCombinedSVG;
need_overlay = opts.WriteOverlayRaster || (need_vectors && include_atlas);
need_render = need_clean || need_overlay || need_vectors;

% Remember where the gui was and how it was set up, and guarantee both are
% put back however this function exits
% (skipped entirely for a channel-stack-only export, which never redraws -
% worth having when the gui itself is slow, e.g. over a remote session)
if need_render
    original_slice = gui_data.curr_slice;
    view_state = dlh.restore_view(histology_gui);
    restorer = onCleanup(@() local_restore(histology_gui,original_slice,view_state)); %#ok<NASGU>
end

n_slices = length(gui_data.data);

for curr_slice = slices

    % Move gui to this slice (only matters if something will redraw)
    if need_render
        gui_data = guidata(histology_gui);
        gui_data.curr_slice = curr_slice;
        guidata(histology_gui,gui_data);
    end

    fprintf('dlh: exporting slice %d (of %d)...\n',curr_slice,n_slices);

    base = fullfile(output_dir,sprintf('%s_slice%02d',prefix,curr_slice));
    im_size = [];
    clean_file = '';
    clean_is_temp = false;

    % --- Raw channel stack for Fiji ------------------------------------
    % (straight from gui_data.data, no compositing and no redraw)
    if opts.WriteChannelStack
        [im_channels,channel_info] = dlh.slice_channels(histology_gui,curr_slice);
        stack_file = [base '_channels.tif'];
        dlh.write_channel_tiff(stack_file,im_channels,channel_info, ...
            'Compression',opts.ChannelStackCompression, ...
            'ImageJHeader',opts.ImageJHeader);
        files{end+1} = stack_file; %#ok<AGROW>
        clear im_channels
    end

    % --- Histology raster, current colours, no overlay -----------------
    if need_clean
        im_clean = dlh.render_slice(histology_gui,false,false,false);
        im_size = [size(im_clean,1),size(im_clean,2)];

        if opts.WriteCleanRaster
            clean_file = sprintf('%s_image.%s',base,opts.RasterFormat);
        else
            % Only needed as the embed source for the combined SVG
            clean_file = [tempname '.png'];
            clean_is_temp = true;
        end

        imwrite(im_clean,clean_file);
        if ~clean_is_temp
            files{end+1} = clean_file; %#ok<AGROW>
        end
        clear im_clean
    end

    % --- Histology raster with overlay burned in (also gives the aligned
    %     CCF label image used for the vectors) -------------------------
    atlas_slice = [];
    if need_overlay
        [im_overlay,atlas_slice] = dlh.render_slice(histology_gui, ...
            include_atlas,opts.IncludeAnnotations,false);
        im_size = [size(im_overlay,1),size(im_overlay,2)];

        if opts.WriteOverlayRaster
            overlay_file = sprintf('%s_overlay.%s',base,opts.RasterFormat);
            imwrite(im_overlay,overlay_file);
            files{end+1} = overlay_file; %#ok<AGROW>
        end
        clear im_overlay
    end

    if ~need_vectors
        if clean_is_temp && exist(clean_file,'file'); delete(clean_file); end
        continue
    end

    % (annotations-only export with no rasters: still need one redraw so
    % the gui is actually on this slice, and to get the image size)
    if isempty(im_size)
        im_ref = dlh.render_slice(histology_gui,false,false,false);
        im_size = [size(im_ref,1),size(im_ref,2)];
        clear im_ref
    end

    % --- Vectors -------------------------------------------------------
    contours = struct([]);
    if include_atlas && ~isempty(atlas_slice)
        contours = dlh.atlas_contours(atlas_slice,st, ...
            'CollapseDepth',opts.CollapseDepth, ...
            'SimplifyTolerance',opts.SimplifyTolerance, ...
            'MinRegionArea',opts.MinRegionArea, ...
            'IncludeRegions',opts.IncludeRegions);
    end

    shapes = struct([]);
    if opts.IncludeAnnotations
        gui_data = guidata(histology_gui);
        processing = load(gui_data.histology_processing_filename);
        if isfield(processing,'AP_histology_processing')
            shapes = dlh.annotation_shapes( ...
                processing.AP_histology_processing,gui_data.curr_im_idx);
        end
    end

    svg_args = {'AtlasStroke',opts.AtlasStroke, ...
        'AtlasStrokeWidth',opts.AtlasStrokeWidth, ...
        'AtlasFillOpacity',opts.AtlasFillOpacity, ...
        'AnnotationStroke',opts.AnnotationStroke, ...
        'AnnotationStrokeWidth',opts.AnnotationStrokeWidth, ...
        'ShowLabels',opts.ShowLabels, ...
        'LabelFontSize',opts.LabelFontSize};

    if opts.WriteVectorSVG
        vector_file = [base '_vectors.svg'];
        dlh.write_svg(vector_file,im_size,contours,shapes,svg_args{:});
        files{end+1} = vector_file; %#ok<AGROW>
    end

    if opts.WriteCombinedSVG && ~isempty(clean_file)
        combined_file = [base '_combined.svg'];
        dlh.write_svg(combined_file,im_size,contours,shapes, ...
            'ImageFile',clean_file,'EmbedImage',true,svg_args{:});
        files{end+1} = combined_file; %#ok<AGROW>
    end

    if clean_is_temp && exist(clean_file,'file'); delete(clean_file); end

end

fprintf('dlh: wrote %d file(s) to %s\n',numel(files),output_dir);

end


function local_restore(histology_gui,original_slice,view_state)
% Put the gui back on the slice and view settings it started with
try
    gui_data = guidata(histology_gui);
    gui_data.curr_slice = original_slice;
    guidata(histology_gui,gui_data);
    dlh.restore_view(histology_gui,view_state);
catch
    % gui closed mid-export
end
end
