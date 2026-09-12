function histology_gui = find_gui
% histology_gui = dlh.find_gui
%
% Find the open AP_histology figure

histology_gui = findall(groot,'Type','figure','Name','AP histology');

if isempty(histology_gui)
    error('dlh:noGui','No AP_histology window found - run AP_histology first');
end

% If several are open, use the most recently created
histology_gui = histology_gui(1);

end
