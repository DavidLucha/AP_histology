function shapes = annotation_shapes(AP_histology_processing,im_idx)
% shapes = dlh.annotation_shapes(AP_histology_processing,im_idx)
%
% Pull the annotations for one slice out of the processing structure as
% vector shapes. Annotations are already stored as vertex lists in
% histology coordinates, so nothing needs tracing - this just sorts them
% into point/line/polygon and shifts to SVG units.
%
% OUTPUT
% shapes - struct array with fields .label, .type ('point'|'line'|
%          'polygon'), .xy (Nx2 [x y] in SVG units)

arguments
    AP_histology_processing struct
    im_idx (1,1) double
end

shapes = struct('label',{},'type',{},'xy',{});

if ~isfield(AP_histology_processing,'annotation') || ...
        isempty(AP_histology_processing.annotation)
    return
end

for curr_annotation = 1:length(AP_histology_processing.annotation)

    vertices_all = AP_histology_processing.annotation(curr_annotation).vertices_histology;
    if ~iscell(vertices_all) || im_idx > numel(vertices_all)
        continue
    end

    vertices = vertices_all{im_idx};
    if isempty(vertices) || size(vertices,2) < 2
        continue
    end

    switch size(vertices,1)
        case 1
            shape_type = 'point';
        case 2
            shape_type = 'line';
        otherwise
            shape_type = 'polygon';
    end

    new_shape = struct;
    new_shape.label = char(string(AP_histology_processing.annotation(curr_annotation).label));
    new_shape.type = shape_type;
    new_shape.xy = vertices(:,1:2) - 0.5;

    shapes(end+1) = new_shape; %#ok<AGROW>

end

end
