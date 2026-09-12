function state = restore_view(histology_gui,state)
% state = dlh.restore_view(histology_gui)         - capture current state
% dlh.restore_view(histology_gui,state)           - put it back and redraw
%
% Save/restore the AP_histology View menu check state, so exporting with
% overlays toggled never leaves the gui looking different afterwards.

arguments
    histology_gui
    state = []
end

if ~isgraphics(histology_gui)
    return
end

try
    gui_data = guidata(histology_gui);
    view_menu = gui_data.menu.view.Children;
    atlas_idx = contains({view_menu.Text},'atlas','IgnoreCase',true);
    annot_idx = contains({view_menu.Text},'annotation','IgnoreCase',true);

    if isempty(state)
        % Capture mode
        state = struct('atlas',[],'annot',[]);
        if any(atlas_idx); state.atlas = char(view_menu(atlas_idx).Checked); end
        if any(annot_idx); state.annot = char(view_menu(annot_idx).Checked); end
        return
    end

    % Restore mode
    if any(atlas_idx) && ~isempty(state.atlas)
        view_menu(atlas_idx).Checked = state.atlas;
    end
    if any(annot_idx) && ~isempty(state.annot)
        view_menu(annot_idx).Checked = state.annot;
    end
    gui_data.update([],[],histology_gui);
catch
    % gui closed mid-export - nothing to restore
end

end
