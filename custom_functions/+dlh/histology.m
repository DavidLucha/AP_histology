function histology_gui = histology(varargin)
% histology_gui = dlh.histology
%
% Launch AP_histology with the custom figure-export menu attached.
% Drop-in replacement for calling AP_histology directly.

AP_histology(varargin{:});

histology_gui = dlh.find_gui;
dlh.attach(histology_gui);

end
