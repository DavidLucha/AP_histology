function rgb = hex2rgb(hex)
% rgb = hex2rgb(hex)
%
% COMPATIBILITY SHIM. MATLAB gained a built-in hex2rgb in R2024a;
% AP_histology uses it in choose_histology_atlas and
% align_auto_histology_atlas, so those fail on older MATLAB with
% "Unrecognized function or variable 'hex2rgb'".
%
% This folder is NOT added by addpath(genpath(...)) blindly - use
% dlh.setup_path, which drops it whenever the real built-in exists so this
% never shadows MathWorks' version.
%
% Convert hexadecimal colour codes to RGB triplets in [0 1].
%
% INPUT
% hex - char, string, string array or cellstr of colour codes, with or
%       without a leading '#'. 6 digits ('FF8800') or 3-digit shorthand
%       ('F80'). Shorter codes are zero-padded; unreadable entries come
%       back white with a warning rather than erroring, so one bad row in
%       the Allen structure tree can't take down the gui.
%
% OUTPUT
% rgb - N-by-3 double in [0 1]
%
% Covers what AP_histology needs. Not implemented, unlike the R2024a
% built-in: the 'OutputType' name-value pair (single/uint8/uint16) and
% m-by-n-by-3 output for 2-D arrays of codes.

if isempty(hex)
    rgb = zeros(0,3);
    return
end

hex_str = string(hex);
hex_str = hex_str(:);
hex_str = erase(strtrim(hex_str),"#");

n = numel(hex_str);
rgb = ones(n,3);
n_bad = 0;

for curr_color = 1:n

    s = char(hex_str(curr_color));

    if numel(s) == 3
        % 'F80' -> 'FF8800'
        s = reshape(repmat(s,2,1),1,[]);
    elseif numel(s) < 6 && ~isempty(s)
        s = [repmat('0',1,6-numel(s)) s]; %#ok<AGROW>
    end

    if numel(s) ~= 6 || ~all(isstrprop(s,'xdigit'))
        n_bad = n_bad + 1;
        continue    % leave as white
    end

    rgb(curr_color,:) = [ ...
        hex2dec(s(1:2)), ...
        hex2dec(s(3:4)), ...
        hex2dec(s(5:6))] / 255;

end

if n_bad > 0
    warning('hex2rgb:badCode', ...
        '%d colour code(s) could not be parsed - substituted white',n_bad);
end

end
