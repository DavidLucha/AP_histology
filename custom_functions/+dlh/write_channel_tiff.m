function write_channel_tiff(filename,im,channel_info,opts)
% dlh.write_channel_tiff(filename,im,channel_info,...)
%
% Write a raw channel stack as a multi-page TIFF that Fiji opens as a
% composite, one page per channel, at the data's native bit depth.
%
% NAME-VALUE
% Compression   - 'lzw' (default), 'none', 'packbits', 'deflate'. All
%                 lossless. 'none' if a downstream tool is fussy.
% ImageJHeader  - write ImageJ hyperstack metadata so Fiji opens it as a
%                 composite with the channels already separated
%                 (default true). The file is a normal multi-IFD TIFF
%                 either way, so it still opens fine with this off.
% WriteSidecar  - write a .txt next to it listing channel colours and the
%                 colour limits that were set in the gui (default true)

arguments
    filename {mustBeTextScalar}
    im
    channel_info struct = struct([])
    opts.Compression {mustBeMember(opts.Compression, ...
        {'none','lzw','packbits','deflate'})} = 'lzw'
    opts.ImageJHeader (1,1) logical = true
    opts.WriteSidecar (1,1) logical = true
end

filename = char(filename);
n_channels = size(im,3);

if n_channels < 1
    error('dlh:noChannels','Image has no channels');
end

% ImageJ hyperstack metadata. The file still has one IFD per channel, so
% ImageJ reads the pages normally and only takes the dimension info from
% here - it does not trigger ImageJ's single-IFD contiguous-read path.
description = '';
if opts.ImageJHeader
    description = sprintf( ...
        ['ImageJ=1.54f\nimages=%d\nchannels=%d\nslices=1\nframes=1\n' ...
        'hyperstack=true\nmode=composite\nunit=pixel\nloop=false\n'], ...
        n_channels,n_channels);
end

for curr_channel = 1:n_channels

    plane = im(:,:,curr_channel);

    if curr_channel == 1
        write_args = {'WriteMode','overwrite','Compression',opts.Compression};
        if ~isempty(description)
            write_args = [write_args,{'Description',description}]; %#ok<AGROW>
        end
        imwrite(plane,filename,'tif',write_args{:});
    else
        imwrite(plane,filename,'tif', ...
            'WriteMode','append','Compression',opts.Compression);
    end

end

% ---- Sidecar: what each page is, and where the gui had the sliders -----
if opts.WriteSidecar && ~isempty(channel_info)

    [p,f] = fileparts(filename);
    sidecar = fullfile(p,[f '_channels.txt']);

    lines = strings(0,1);
    lines(end+1) = "Channel stack: " + string(f) + ".tif";
    lines(end+1) = sprintf('%d x %d px, %d channel(s), %s', ...
        size(im,2),size(im,1),n_channels,class(im));
    lines(end+1) = "Raw data - no colour limits applied. Set brightness/contrast in Fiji.";
    lines(end+1) = "";
    lines(end+1) = "page  colour (RGB)   gui colour min/max   shown in gui";

    for curr_channel = 1:numel(channel_info)
        lines(end+1) = sprintf('%-5d [%.2f %.2f %.2f]   %-8g %-8g     %s', ...
            channel_info(curr_channel).index, ...
            channel_info(curr_channel).color(1), ...
            channel_info(curr_channel).color(2), ...
            channel_info(curr_channel).color(3), ...
            channel_info(curr_channel).clim(1), ...
            channel_info(curr_channel).clim(2), ...
            string(channel_info(curr_channel).visible));
    end

    lines(end+1) = "";
    lines(end+1) = "In Fiji: Image > Color > Make Composite, then set each channel's LUT";
    lines(end+1) = "to the colour above and adjust with Image > Adjust > Brightness/Contrast.";

    try
        writelines(lines,sidecar);
    catch
        % Sidecar is a convenience - never fail the export over it
    end

end

end
