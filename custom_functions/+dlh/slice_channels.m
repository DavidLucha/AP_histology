function [im,channel_info,im_idx] = slice_channels(histology_gui,slice_num)
% [im,channel_info,im_idx] = dlh.slice_channels(histology_gui,slice_num)
%
% Raw, full-bit-depth channel data for one slice, with the rigid transform
% (rotate/translate/flip) applied so it sits in the same geometry as the
% aligned atlas and the exported vectors.
%
% Nothing is scaled, clipped or composited - the colour min/max you have set
% in the gui are NOT applied. That's the point: this is the stack to take
% into Fiji and set brightness/contrast on properly.
%
% Does not redraw the gui, so it's cheap even when AP_histology itself is
% sluggish (e.g. over a remote HPC session).
%
% OUTPUTS
% im            - rows x cols x channels, native class (usually uint16)
% channel_info  - per-channel struct: .index .color .clim .visible
% im_idx        - index into gui_data.data (accounts for slice re-ordering)

arguments
    histology_gui matlab.ui.Figure
    slice_num double = []
end

gui_data = guidata(histology_gui);

if ~isfield(gui_data,'data') || isempty(gui_data.data)
    error('dlh:noImages','No images loaded in AP_histology');
end

if isempty(slice_num)
    slice_num = gui_data.curr_slice;
end

processing = load(gui_data.histology_processing_filename);
AP_histology_processing = processing.AP_histology_processing;

% Map slice position -> image index (same rule AP_histology's update uses)
if isfield(AP_histology_processing,'image_order')
    im_idx = AP_histology_processing.image_order(slice_num);
else
    im_idx = slice_num;
end

% Raw data, rigid transform only
im = ap_histology.rigid_transform( ...
    gui_data.data{im_idx},im_idx,AP_histology_processing);

% Per-channel metadata (so you know which page is which in Fiji)
n_channels = size(im,3);
channel_info = struct('index',{},'color',{},'clim',{},'visible',{});

for curr_channel = 1:n_channels
    entry = struct;
    entry.index = curr_channel;
    if isfield(gui_data,'channel_colors') && size(gui_data.channel_colors,1) >= curr_channel
        entry.color = gui_data.channel_colors(curr_channel,:);
    else
        entry.color = [1,1,1];
    end
    if isfield(gui_data,'clim') && size(gui_data.clim,1) >= curr_channel
        entry.clim = gui_data.clim(curr_channel,:);
    else
        entry.clim = [NaN,NaN];
    end
    if isfield(gui_data,'channel_visibility') && numel(gui_data.channel_visibility) >= curr_channel
        entry.visible = logical(gui_data.channel_visibility(curr_channel));
    else
        entry.visible = true;
    end
    channel_info(end+1) = entry; %#ok<AGROW>
end

end
