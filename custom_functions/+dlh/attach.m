function menu_h = attach(histology_gui)
% menu_h = dlh.attach(histology_gui)
%
% Add the custom "Export (figures)" menu to an open AP_histology window.
%
% This is the only point of contact with AP_histology: the menu is injected
% into the figure at runtime, so no upstream file is modified and pulling
% from petersaj/AP_histology can never conflict with it.
%
% Usage:
%   AP_histology; dlh.attach
% or just:
%   dlh.histology
%
% Safe to call more than once (the old menu is replaced).

arguments
    histology_gui = []
end

if isempty(histology_gui)
    histology_gui = dlh.find_gui;
end

% Remove any previously attached menu
delete(findall(histology_gui,'Tag','dlh_export_menu'));

menu_h = uimenu(histology_gui,'Text','Export (figures)','Tag','dlh_export_menu');

uimenu(menu_h,'Text','Export image + vectors...', ...
    'MenuSelectedFcn',{@dlh.export_dialog,histology_gui});

uimenu(menu_h,'Text','Quick export: current slice','Separator','on', ...
    'MenuSelectedFcn',@(~,~) local_quick(histology_gui));

uimenu(menu_h,'Text','Open export folder', ...
    'MenuSelectedFcn',@(~,~) local_open_folder(histology_gui));

end


function local_quick(histology_gui)
% Export the current slice with defaults, no dialog
try
    files = dlh.export_slices(histology_gui);
    fprintf('dlh: wrote:\n%s\n',strjoin(files,newline));
catch ME
    errordlg(ME.message,'Export failed');
end
end


function local_open_folder(histology_gui)
gui_data = guidata(histology_gui);
output_dir = fullfile(gui_data.image_path,'figure_export');
s = getappdata(groot,'dlh_export_settings');
if isstruct(s) && isfield(s,'output_dir') && ~isempty(s.output_dir)
    output_dir = s.output_dir;
end
if ~exist(output_dir,'dir')
    errordlg(sprintf('Nothing exported yet (%s does not exist)',output_dir), ...
        'No export folder');
    return
end
if ismac
    system(sprintf('open "%s"',output_dir));
elseif ispc
    winopen(output_dir);
else
    system(sprintf('xdg-open "%s" &',output_dir));
end
end
