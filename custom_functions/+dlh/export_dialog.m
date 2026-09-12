function export_dialog(~,~,histology_gui)
% dlh.export_dialog([],[],histology_gui)
%
% Options dialog for dlh.export_slices. Hooked onto the "Export (figures)"
% menu by dlh.attach, but can also be called directly:
%   dlh.export_dialog([],[],findall(groot,'Name','AP histology'))

if nargin < 3 || isempty(histology_gui)
    histology_gui = dlh.find_gui;
end

gui_data = guidata(histology_gui);
if ~isfield(gui_data,'data') || isempty(gui_data.data)
    errordlg('Load images in AP_histology first.','Nothing to export');
    return
end

% Restore last-used settings (per MATLAB session)
s = getappdata(groot,'dlh_export_settings');
if isempty(s)
    s = struct;
end
def = @(f,v) local_default(s,f,v);

default_dir = fullfile(gui_data.image_path,'figure_export');
[~,default_prefix] = fileparts(gui_data.image_path);

% ---- Build dialog ------------------------------------------------------
n_rows = 20;
fig = uifigure('Name','Export histology figures', ...
    'Position',[100,100,560,30*n_rows+40],'Resize','on');

grid = uigridlayout(fig,[n_rows,3]);
grid.RowHeight = repmat({26},1,n_rows);
grid.ColumnWidth = {190,'1x',90};
grid.RowSpacing = 4;

h = struct;
r = 0;

% Output folder
r = r+1;
local_label(grid,r,1,'Output folder');
h.output_dir = uieditfield(grid,'text','Value',def('output_dir',default_dir));
h.output_dir.Layout.Row = r; h.output_dir.Layout.Column = 2;
browse = uibutton(grid,'Text','Browse...');
browse.Layout.Row = r; browse.Layout.Column = 3;
browse.ButtonPushedFcn = @(~,~) local_browse(h.output_dir);

% Prefix
r = r+1;
local_label(grid,r,1,'File prefix');
h.prefix = uieditfield(grid,'text','Value',def('prefix',default_prefix));
h.prefix.Layout.Row = r; h.prefix.Layout.Column = 2;

% Slices
r = r+1;
local_label(grid,r,1,'Slices');
h.slices = uidropdown(grid,'Items',{'Current slice only', ...
    sprintf('All slices (1-%d)',length(gui_data.data))}, ...
    'Value',def('slices','Current slice only'));
h.slices.Layout.Row = r; h.slices.Layout.Column = 2;

% Raster format
r = r+1;
local_label(grid,r,1,'Raster format');
h.raster_format = uidropdown(grid,'Items',{'png','tif'}, ...
    'Value',def('raster_format','png'));
h.raster_format.Layout.Row = r; h.raster_format.Layout.Column = 2;

% ---- Files to write
r = r+1; local_header(grid,r,'Files to write');

r = r+1;
h.channel_stack = local_check(grid,r, ...
    'Raw channel stack .tif for Fiji (full bit depth, no B/C applied)', ...
    def('channel_stack',true));
r = r+1;
h.clean_raster = local_check(grid,r,'Histology image, no overlay (current colours)', ...
    def('clean_raster',true));
r = r+1;
h.overlay_raster = local_check(grid,r,'Histology image with overlay burned in', ...
    def('overlay_raster',false));
r = r+1;
h.vector_svg = local_check(grid,r,'SVG overlay, transparent background', ...
    def('vector_svg',true));
r = r+1;
h.combined_svg = local_check(grid,r,'SVG with histology embedded (self-contained)', ...
    def('combined_svg',true));

% ---- Overlay contents
r = r+1; local_header(grid,r,'Overlay contents');

r = r+1;
h.include_atlas = local_check(grid,r,'CCF boundaries',def('include_atlas',true));

r = r+1;
local_label(grid,r,1,'   CCF detail (0 = as shown)');
h.collapse_depth = uispinner(grid,'Limits',[0,12],'Step',1, ...
    'Value',def('collapse_depth',0),'ValueDisplayFormat','%d');
h.collapse_depth.Layout.Row = r; h.collapse_depth.Layout.Column = 2;
local_label(grid,r,3,'depth');

r = r+1;
local_label(grid,r,1,'   Simplify edges (0-1)');
h.simplify = uispinner(grid,'Limits',[0,0.05],'Step',0.0005, ...
    'Value',def('simplify',0.001),'ValueDisplayFormat','%.4f');
h.simplify.Layout.Row = r; h.simplify.Layout.Column = 2;

r = r+1;
local_label(grid,r,1,'   Outline colour / width');
h.atlas_stroke = uieditfield(grid,'text','Value',def('atlas_stroke','#FFFFFF'));
h.atlas_stroke.Layout.Row = r; h.atlas_stroke.Layout.Column = 2;
h.atlas_width = uispinner(grid,'Limits',[0.1,50],'Step',0.5, ...
    'Value',def('atlas_width',2),'ValueDisplayFormat','%.1f');
h.atlas_width.Layout.Row = r; h.atlas_width.Layout.Column = 3;

r = r+1;
local_label(grid,r,1,'   Fill regions (0 = outline only)');
h.fill_opacity = uispinner(grid,'Limits',[0,1],'Step',0.05, ...
    'Value',def('fill_opacity',0),'ValueDisplayFormat','%.2f');
h.fill_opacity.Layout.Row = r; h.fill_opacity.Layout.Column = 2;

r = r+1;
h.include_annotations = local_check(grid,r,'Annotations', ...
    def('include_annotations',true));

r = r+1;
local_label(grid,r,1,'   Annotation colour / width');
h.annot_stroke = uieditfield(grid,'text','Value',def('annot_stroke','#FFFF00'));
h.annot_stroke.Layout.Row = r; h.annot_stroke.Layout.Column = 2;
h.annot_width = uispinner(grid,'Limits',[0.1,50],'Step',0.5, ...
    'Value',def('annot_width',3),'ValueDisplayFormat','%.1f');
h.annot_width.Layout.Row = r; h.annot_width.Layout.Column = 3;

r = r+1;
h.show_labels = local_check(grid,r,'Annotation labels as editable SVG text', ...
    def('show_labels',true));

% ---- Buttons
r = r+1;
export_button = uibutton(grid,'Text','Export');
export_button.Layout.Row = r; export_button.Layout.Column = 2;
export_button.BackgroundColor = [0.85,0.92,1];
export_button.FontWeight = 'bold';
cancel_button = uibutton(grid,'Text','Cancel');
cancel_button.Layout.Row = r; cancel_button.Layout.Column = 3;

export_button.ButtonPushedFcn = @(~,~) local_export(fig,h,histology_gui);
cancel_button.ButtonPushedFcn = @(~,~) delete(fig);

end


% =======================================================================

function local_export(fig,h,histology_gui)

if ~isgraphics(histology_gui)
    uialert(fig,'The AP_histology window has been closed.','No gui');
    return
end

gui_data = guidata(histology_gui);

if startsWith(h.slices.Value,'All')
    slices = 1:length(gui_data.data);
else
    slices = gui_data.curr_slice;
end

% Remember settings for next time
s = struct( ...
    'output_dir',h.output_dir.Value, ...
    'prefix',h.prefix.Value, ...
    'slices',h.slices.Value, ...
    'raster_format',h.raster_format.Value, ...
    'channel_stack',h.channel_stack.Value, ...
    'clean_raster',h.clean_raster.Value, ...
    'overlay_raster',h.overlay_raster.Value, ...
    'vector_svg',h.vector_svg.Value, ...
    'combined_svg',h.combined_svg.Value, ...
    'include_atlas',h.include_atlas.Value, ...
    'collapse_depth',h.collapse_depth.Value, ...
    'simplify',h.simplify.Value, ...
    'atlas_stroke',h.atlas_stroke.Value, ...
    'atlas_width',h.atlas_width.Value, ...
    'fill_opacity',h.fill_opacity.Value, ...
    'include_annotations',h.include_annotations.Value, ...
    'annot_stroke',h.annot_stroke.Value, ...
    'annot_width',h.annot_width.Value, ...
    'show_labels',h.show_labels.Value);
setappdata(groot,'dlh_export_settings',s);

progress = uiprogressdlg(fig,'Title','Exporting', ...
    'Message','Rendering and vectorising...','Indeterminate','on');

try
    files = dlh.export_slices(histology_gui, ...
        'Slices',slices, ...
        'OutputDir',s.output_dir, ...
        'Prefix',s.prefix, ...
        'RasterFormat',s.raster_format, ...
        'WriteChannelStack',s.channel_stack, ...
        'WriteCleanRaster',s.clean_raster, ...
        'WriteOverlayRaster',s.overlay_raster, ...
        'WriteVectorSVG',s.vector_svg, ...
        'WriteCombinedSVG',s.combined_svg, ...
        'IncludeAtlas',s.include_atlas, ...
        'IncludeAnnotations',s.include_annotations, ...
        'CollapseDepth',s.collapse_depth, ...
        'SimplifyTolerance',s.simplify, ...
        'AtlasStroke',s.atlas_stroke, ...
        'AtlasStrokeWidth',s.atlas_width, ...
        'AtlasFillOpacity',s.fill_opacity, ...
        'AnnotationStroke',s.annot_stroke, ...
        'AnnotationStrokeWidth',s.annot_width, ...
        'ShowLabels',s.show_labels);
catch ME
    close(progress);
    uialert(fig,ME.message,'Export failed');
    return
end

close(progress);
delete(fig);

fprintf('dlh: export complete\n');
msgbox(sprintf('Wrote %d file(s) to:\n%s',numel(files),s.output_dir), ...
    'Export complete');

end


function local_browse(edit_h)
d = uigetdir(edit_h.Value,'Select output folder');
if ischar(d)
    edit_h.Value = d;
end
end


function label_h = local_label(grid,row,col,text)
label_h = uilabel(grid,'Text',text);
label_h.Layout.Row = row;
label_h.Layout.Column = col;
end


function local_header(grid,row,text)
label_h = uilabel(grid,'Text',text,'FontWeight','bold');
label_h.Layout.Row = row;
label_h.Layout.Column = [1,3];
end


function check_h = local_check(grid,row,text,value)
check_h = uicheckbox(grid,'Text',text,'Value',logical(value));
check_h.Layout.Row = row;
check_h.Layout.Column = [1,3];
end


function v = local_default(s,field,fallback)
if isstruct(s) && isfield(s,field) && ~isempty(s.(field))
    v = s.(field);
else
    v = fallback;
end
end
