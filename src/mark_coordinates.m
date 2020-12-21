
img = imread('../data/keyboard.png');

figure(1); clf
set(gcf, 'position', [0 460 1922 535])
image('xdata', 1:909, 'ydata', 1:261, 'cdata', flipud(img))
axis equal tight
hold on

keyLocations = struct('x', [], 'y', [], 'index', [], 'plus_shift', []);
for i = 33:126
    disp([num2str(i-32), ': ', char(i)])
    [x, y, button] = ginput(1);
    keyLocations(i-32).x = x;
    keyLocations(i-32).y = y;
    keyLocations(i-32).index = i;
    keyLocations(i-32).plus_shift = button ~= 1;
    text(keyLocations(i-32).x, keyLocations(i-32).y, ...
	    char(keyLocations(i-32).index),...
        'HorizontalAlignment', 'center', 'fontsize', 13)
end

save('../data/keyboard_keys_coordinates.mat', 'keyLocations')


% Only plotting the keyboard key characters:

% for i = 33:126
%     if keyLocations(i-32).plus_shift
%         col = 'red';
%     else
%         col = 'blue';
%     end
%     text(keyLocations(i-32).x, keyLocations(i-32).y,...
%         char(keyLocations(i-32).index),...
%         'HorizontalAlignment', 'center', 'fontsize', 13, 'color', col)
% end

% write in csv format to std_out.
% copied it to the file "../data/keyboard_keys_coordinates.csv".
fprintf('\n\n\nindex;x;y;plus_shift\n')
for i = 33:126
    fprintf('%i;%1.2f;%1.2f;%i\n',...
        keyLocations(i-32).index, keyLocations(i-32).x,...
        keyLocations(i-32).y, keyLocations(i-32).plus_shift);
end
