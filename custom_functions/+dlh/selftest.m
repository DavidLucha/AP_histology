function selftest(output_dir)
% dlh.selftest
%
% Exercise the vectorising and SVG writing on a synthetic label image,
% without needing images, the atlas, or the gui. Run this once after
% installing to confirm the pieces work on your MATLAB version.
%
% Writes dlh_selftest.svg (and a matching png) and opens it.

arguments
    output_dir {mustBeTextScalar} = tempdir
end

fprintf('dlh selftest\n');

% ---- Synthetic "atlas slice": three nested regions ---------------------
im_size = [400,600];
[xx,yy] = meshgrid(1:im_size(2),1:im_size(1));

label_im = ones(im_size);                                   % 1 = background
label_im((xx-300).^2/200^2 + (yy-200).^2/150^2 < 1) = 2;    % big ellipse
label_im((xx-230).^2/60^2  + (yy-180).^2/50^2  < 1) = 3;    % inner blob
label_im((xx-380).^2/40^2  + (yy-240).^2/70^2  < 1) = 4;    % second blob

% ---- Minimal structure tree with the columns dlh uses ------------------
st = table( ...
    int32([997;8;100;101]), ...
    {'root';'TEST';'PO';'VPM'}, ...
    {'root';'test region';'Posterior complex';'Ventral posteromedial'}, ...
    {'/997/';'/997/8/';'/997/8/100/';'/997/8/101/'}, ...
    {'FFFFFF';'8599CC';'FF909F';'4DA1A9'}, ...
    'VariableNames',{'id','acronym','name','structure_id_path','color_hex_triplet'});

% ---- Vectorise ---------------------------------------------------------
fprintf('  atlas_contours (as displayed)...\n');
contours = dlh.atlas_contours(label_im,st,'SimplifyTolerance',0.001);
fprintf('    %d structure(s): %s\n',numel(contours), ...
    strjoin({contours.acronym},', '));
assert(~isempty(contours),'no contours found');

fprintf('  atlas_contours (collapsed to depth 1)...\n');
contours_collapsed = dlh.atlas_contours(label_im,st,'CollapseDepth',1);
fprintf('    %d structure(s): %s\n',numel(contours_collapsed), ...
    strjoin({contours_collapsed.acronym},', '));

fprintf('  atlas_contours (PO only)...\n');
contours_po = dlh.atlas_contours(label_im,st,'IncludeRegions',"PO");
fprintf('    %d structure(s)\n',numel(contours_po));

% ---- Fake annotations --------------------------------------------------
processing.annotation(1).label = 'probe 1';
processing.annotation(1).vertices_histology = {[100,60;260,330]};
processing.annotation(2).label = 'injection';
processing.annotation(2).vertices_histology = {[380,180;440,190;430,260;370,250]};
shapes = dlh.annotation_shapes(processing,1);
fprintf('  annotation_shapes: %d shape(s) (%s)\n',numel(shapes), ...
    strjoin({shapes.type},', '));

% ---- Write a background raster so alignment can be eyeballed -----------
im_rgb = repmat(im2uint8(mat2gray(label_im)),1,1,3);
png_file = fullfile(output_dir,'dlh_selftest.png');
imwrite(im_rgb,png_file);

% ---- Write SVGs --------------------------------------------------------
svg_file = fullfile(output_dir,'dlh_selftest.svg');
dlh.write_svg(svg_file,im_size,contours,shapes, ...
    'ImageFile',png_file,'EmbedImage',true, ...
    'AtlasStroke','#00FF00','AtlasStrokeWidth',2, ...
    'AtlasFillOpacity',0.25);

svg_overlay = fullfile(output_dir,'dlh_selftest_vectors.svg');
dlh.write_svg(svg_overlay,im_size,contours,shapes);

fprintf('  wrote:\n    %s\n    %s\n',svg_file,svg_overlay);
fprintf('dlh selftest passed - open the SVG and check the outlines sit on the shapes.\n');

if usejava('desktop')
    web(svg_file,'-browser');
end

end
