function [im,atlas_slice] = render_slice(histology_gui,show_atlas,show_annotations,restore_view)
% [im,atlas_slice] = dlh.render_slice(histology_gui,show_atlas,show_annotations,restore_view)
%
% Return the FULL-RESOLUTION composited RGB image for the slice currently
% displayed in AP_histology, with the current channel colours/limits, and
% with the CCF/annotation overlays optionally switched on or off.
%
% This deliberately re-uses AP_histology's own renderer: it flips the View
% menu checkboxes, asks the gui to redraw, and reads the resulting image
% CData (which is full resolution - only the screen display is downsampled).
% Nothing about the colour compositing is duplicated here, so this stays
% correct if upstream changes how images are built.
%
% INPUTS
% histology_gui       - handle to the AP_histology figure
% show_atlas          - draw CCF boundaries (default false)
% show_annotations    - draw annotations + labels (default false)
% restore_view        - put the View menu back and redraw afterwards
%                       (default true). Set false when making several
%                       calls in a row, and restore once at the end with
%                       dlh.restore_view.
%
% OUTPUTS
% im                  - uint8 MxNx3 image
% atlas_slice         - aligned CCF label image for this slice in histology
%                       coordinates ([] if the atlas was not drawn)

arguments
    histology_gui matlab.ui.Figure
    show_atlas (1,1) logical = false
    show_annotations (1,1) logical = false
    restore_view (1,1) logical = true
end

gui_data = guidata(histology_gui);

if ~isfield(gui_data,'data') || isempty(gui_data.data)
    error('dlh:noImages','No images loaded in AP_histology');
end

% Find the View menu entries
view_menu = gui_data.menu.view.Children;
atlas_idx = contains({view_menu.Text},'atlas','IgnoreCase',true);
annot_idx = contains({view_menu.Text},'annotation','IgnoreCase',true);

% Remember current check state, and guarantee it is put back even on error
if restore_view
    state = struct('atlas',[],'annot',[]);
    if any(atlas_idx); state.atlas = char(view_menu(atlas_idx).Checked); end
    if any(annot_idx); state.annot = char(view_menu(annot_idx).Checked); end
    cleanup = onCleanup(@() dlh.restore_view(histology_gui,state)); %#ok<NASGU>
end

% The atlas can only be drawn if aligned slices have been loaded
atlas_available = isfield(gui_data,'atlas_slices') && ~isempty(gui_data.atlas_slices);

if any(atlas_idx)
    view_menu(atlas_idx).Checked = local_onoff(show_atlas && atlas_available);
end
if any(annot_idx)
    view_menu(annot_idx).Checked = local_onoff(show_annotations);
end

% Redraw through AP_histology's own update function
gui_data.update([],[],histology_gui);

% Read back the composited image
gui_data = guidata(histology_gui);
im = gui_data.im_h.CData;

if isa(im,'double') || isa(im,'single')
    im = im2uint8(min(max(im,0),1));
end

% Grab the aligned atlas label image (stored by update_image on redraw)
atlas_slice = [];
if show_atlas && atlas_available && isfield(gui_data,'curr_atlas_slice')
    atlas_slice = gui_data.curr_atlas_slice;
end

end


function s = local_onoff(tf)
if tf; s = 'on'; else; s = 'off'; end
end
