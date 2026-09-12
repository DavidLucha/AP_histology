function write_svg(filename,im_size,contours,shapes,opts)
% dlh.write_svg(filename,im_size,contours,shapes,...)
%
% Write CCF outlines and annotations to an SVG, optionally over the
% histology image. Every structure becomes its own named group, so it
% arrives in Illustrator/Inkscape as a selectable, named object.
%
% INPUTS
% filename  - output .svg path
% im_size   - [rows cols] of the histology image the vectors belong to
% contours  - from dlh.atlas_contours ([] to omit)
% shapes    - from dlh.annotation_shapes ([] to omit)
%
% NAME-VALUE
% ImageFile             - path to a raster of the same slice. If empty the
%                         SVG has a transparent background (drop it over
%                         the exported image in Illustrator - they line up
%                         pixel for pixel).
% EmbedImage            - true (default) base64-embeds ImageFile so the SVG
%                         is self-contained; false links it by relative
%                         filename (keep both files in the same folder).
% AtlasStroke           - CCF outline colour (default '#FFFFFF')
% AtlasStrokeWidth      - CCF outline width in px (default 2)
% AtlasFillOpacity      - 0 (default) = outlines only. >0 fills each
%                         structure with its Allen CCF colour at that
%                         opacity.
% AnnotationStroke      - annotation colour (default '#FFFF00')
% AnnotationStrokeWidth - annotation width in px (default 3)
% ShowLabels            - write annotation labels as SVG text (default true)
% LabelFontSize         - 0 (default) = scale to image, matching the gui

arguments
    filename {mustBeTextScalar}
    im_size (1,2) double
    contours struct = struct([])
    shapes struct = struct([])
    opts.ImageFile {mustBeTextScalar} = ''
    opts.EmbedImage (1,1) logical = true
    opts.AtlasStroke {mustBeTextScalar} = '#FFFFFF'
    opts.AtlasStrokeWidth (1,1) double = 2
    opts.AtlasFillOpacity (1,1) double {mustBeInRange(opts.AtlasFillOpacity,0,1)} = 0
    opts.AnnotationStroke {mustBeTextScalar} = '#FFFF00'
    opts.AnnotationStrokeWidth (1,1) double = 3
    opts.ShowLabels (1,1) logical = true
    opts.LabelFontSize (1,1) double = 0
end

im_h = im_size(1);
im_w = im_size(2);

font_size = opts.LabelFontSize;
if font_size <= 0
    font_size = min(200,round(max(im_size)*0.03));
end

fid = fopen(filename,'w');
if fid == -1
    error('dlh:cannotWrite','Could not open %s for writing',filename);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n');
fprintf(fid,['<svg xmlns="http://www.w3.org/2000/svg" ' ...
    'xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" ' ...
    'width="%dpx" height="%dpx" viewBox="0 0 %d %d" ' ...
    'shape-rendering="geometricPrecision">\n'],im_w,im_h,im_w,im_h);
fprintf(fid,'  <title>%s</title>\n',local_xml(char(filename)));

% ---- Histology image layer --------------------------------------------
if ~isempty(opts.ImageFile) && exist(opts.ImageFile,'file')
    if opts.EmbedImage
        href = local_datauri(opts.ImageFile);
    else
        [~,f,e] = fileparts(opts.ImageFile);
        href = [f e];
    end
    fprintf(fid,'  <g id="histology_image">\n');
    fprintf(fid,['    <image x="0" y="0" width="%d" height="%d" ' ...
        'preserveAspectRatio="none" xlink:href="%s"/>\n'],im_w,im_h,href);
    fprintf(fid,'  </g>\n');
end

% ---- CCF boundaries ----------------------------------------------------
if ~isempty(contours)

    fprintf(fid,['  <g id="CCF_boundaries" fill="none" stroke="%s" ' ...
        'stroke-width="%.3f" stroke-linejoin="round" stroke-linecap="round">\n'], ...
        local_xml(opts.AtlasStroke),opts.AtlasStrokeWidth);

    used_ids = string.empty;

    for curr_contour = 1:numel(contours)

        group_id = local_id(contours(curr_contour).acronym,used_ids);
        used_ids(end+1) = string(group_id); %#ok<AGROW>

        if opts.AtlasFillOpacity > 0
            fill_attr = sprintf('fill="%s" fill-opacity="%.3f" fill-rule="evenodd"', ...
                contours(curr_contour).color,opts.AtlasFillOpacity);
        else
            fill_attr = 'fill="none"';
        end

        d = local_pathdata(contours(curr_contour).boundaries);
        if isempty(d)
            continue
        end

        fprintf(fid,'    <g id="%s"><title>%s</title>\n',group_id, ...
            local_xml(contours(curr_contour).name));
        fprintf(fid,'      <path %s d="%s"/>\n',fill_attr,d);
        fprintf(fid,'    </g>\n');

    end

    fprintf(fid,'  </g>\n');

end

% ---- Annotations -------------------------------------------------------
if ~isempty(shapes)

    fprintf(fid,['  <g id="annotations" fill="none" stroke="%s" ' ...
        'stroke-width="%.3f" stroke-linejoin="round" stroke-linecap="round">\n'], ...
        local_xml(opts.AnnotationStroke),opts.AnnotationStrokeWidth);

    used_ids = string.empty;

    for curr_shape = 1:numel(shapes)

        group_id = local_id(shapes(curr_shape).label,used_ids);
        used_ids(end+1) = string(group_id); %#ok<AGROW>

        xy = shapes(curr_shape).xy;

        fprintf(fid,'    <g id="%s"><title>%s</title>\n',group_id, ...
            local_xml(shapes(curr_shape).label));

        switch shapes(curr_shape).type
            case 'point'
                fprintf(fid,['      <circle cx="%.2f" cy="%.2f" r="%.2f" ' ...
                    'fill="%s" stroke="none"/>\n'],xy(1,1),xy(1,2), ...
                    max(2,opts.AnnotationStrokeWidth*1.5),local_xml(opts.AnnotationStroke));
            case 'line'
                fprintf(fid,'      <path d="%s"/>\n',local_subpath(xy,false));
            otherwise
                fprintf(fid,'      <path d="%s"/>\n',local_subpath(xy,true));
        end

        fprintf(fid,'    </g>\n');

    end

    fprintf(fid,'  </g>\n');

    % ---- Annotation labels (separate layer so they can be hidden) ------
    if opts.ShowLabels
        fprintf(fid,['  <g id="annotation_labels" fill="%s" stroke="none" ' ...
            'font-family="Helvetica, Arial, sans-serif" font-size="%d">\n'], ...
            local_xml(opts.AnnotationStroke),font_size);
        for curr_shape = 1:numel(shapes)
            centroid = mean(shapes(curr_shape).xy,1);
            fprintf(fid,['    <text x="%.2f" y="%.2f" text-anchor="middle">' ...
                '%s</text>\n'],centroid(1),centroid(2), ...
                local_xml(shapes(curr_shape).label));
        end
        fprintf(fid,'  </g>\n');
    end

end

fprintf(fid,'</svg>\n');

end


function d = local_pathdata(boundaries)
% Combine all boundaries of one structure into a single path (holes are
% cut out by the evenodd fill rule)

parts = cell(1,numel(boundaries));
for curr_b = 1:numel(boundaries)
    parts{curr_b} = local_subpath(boundaries{curr_b},true);
end
parts = parts(~cellfun(@isempty,parts));
d = strjoin(parts,' ');

end


function s = local_subpath(xy,close_path)
% Nx2 [x y] -> SVG path data

if size(xy,1) < 2
    s = '';
    return
end

s = sprintf('M %.2f %.2f L',xy(1,1),xy(1,2));
s = [s sprintf(' %.2f %.2f',xy(2:end,:)')];
if close_path
    s = [s ' Z'];
end

end


function id = local_id(name,used)
% XML-safe, unique, human-readable group id (becomes the Illustrator
% object name)

id = regexprep(char(string(name)),'[^A-Za-z0-9_\-]','_');
if isempty(id)
    id = 'region';
end
if ~isletter(id(1)) && id(1) ~= '_'
    id = ['x' id];
end

base = id;
n = 1;
while any(strcmp(string(id),used))
    n = n + 1;
    id = sprintf('%s_%d',base,n);
end

end


function s = local_xml(str)
% Escape XML entities

s = char(string(str));
s = strrep(s,'&','&amp;');
s = strrep(s,'<','&lt;');
s = strrep(s,'>','&gt;');
s = strrep(s,'"','&quot;');

end


function uri = local_datauri(image_file)
% base64 data URI for embedding a raster in the SVG

fid = fopen(image_file,'r');
bytes = fread(fid,Inf,'*uint8');
fclose(fid);

[~,~,ext] = fileparts(image_file);
switch lower(ext)
    case {'.tif','.tiff'}
        mime = 'image/tiff';
    case {'.jpg','.jpeg'}
        mime = 'image/jpeg';
    otherwise
        mime = 'image/png';
end

uri = ['data:' mime ';base64,' char(matlab.net.base64encode(bytes(:)'))];

end
