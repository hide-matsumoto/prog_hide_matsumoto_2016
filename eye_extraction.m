% input:
% videoName: name of the video file for extraction (avi file)
% dataFolder: name of the folder that the video file is located
% saveFolder_home: name of the folder that extracted data and figures are saved

function eye_extraction(videoName,dataFolder,saveFolder_home)

mouseid = videoName(end-8:end-4);
dateid = videoName(1:17);

saveName = ['eye_' mouseid '_' dateid];
video_filename = [dataFolder videoName];

vobj = VideoReader(video_filename);
frame_rate = vobj.FrameRate;
saveFolder = [saveFolder_home saveName filesep];
if ~exist(saveFolder, 'dir')
    mkdir(saveFolder)
end
%% automatic detection of pupil threshold
iSample = 100;
snapshot = read(vobj, iSample);
snapshot = snapshot(:,:,1);

W = size(snapshot,1);
H = size(snapshot,2);
min_p_area = round(3.14*(W/16)^2);
min_eye_size = W*H/2;

pi = double(snapshot(:));
pi = sort(pi,'ascend');

lowthrs = pi(min_p_area);
highthres = pi(min_eye_size);
bins = lowthrs:1:highthres;
[~, minidx] = min(hist(pi,bins));
THRES_pupil = bins(minidx)+15; % +15 for normal mice

% check the biggest connected area, if long axis bigger than 0.5 of
% of the image width, lower threshold
bimag = ~im2bw(snapshot, THRES_pupil/255);
r_stats = regionprops(bimag,{'Area','MajorAxisLength'});
[~,idx] = max([r_stats.Area]);
while r_stats(idx).MajorAxisLength > 0.6*W
    THRES_pupil = THRES_pupil - 10;
    bimag = ~im2bw(snapshot, THRES_pupil/255);
    r_stats = regionprops(bimag,{'Area','MajorAxisLength'});
    [~,idx] = max([r_stats.Area]);
end

% save the image the test threshold
ftest = figure;
subplot(3,1,1)
imshow(snapshot)
subplot(3,1,2)
imshow(im2bw(snapshot, THRES_pupil/255));
title(['thres: ' num2str(THRES_pupil)])
subplot(3,1,3)
hist(pi,[50:1:255])
hold on; vline(lowthrs);
vline(highthres);vline(THRES_pupil)
ylim([0 1000])
title(videoName)

saveas(ftest,[saveFolder 'pupil_thres.png']);
pause(1)
close(ftest)

%% automatic detection of eye threshold

bins = 60:1:255;
thresIdx = find(diff(hist(pi,bins))>500,1,'first')-20;
THRES_eye = bins(thresIdx);
% save the image the test threshold
ftest = figure;
subplot(3,1,1)
imshow(snapshot)
subplot(3,1,2)
imshow(im2bw(snapshot, THRES_eye/255));
title(['thres: ' num2str(THRES_eye)])

subplot(3,1,3)
hist(pi,[50:1:255])
hold on; vline(THRES_eye);
title(videoName);ylim([0 1000])

saveas(ftest,[saveFolder 'eye_thres.png']);
pause(1)
close(ftest)

%% calculating eye area
se = {};
se{1} = strel('disk',3);
se{2} = strel('disk',10,0); %se{2} = strel('disk',50,0);
se_eye = strel('disk',4);

tstart = tic;
eye_area =nan(length(vobj.NumberOfFrames),1);
eye_ect =nan(length(vobj.NumberOfFrames),1);
eye_brightness =nan(length(vobj.NumberOfFrames),1);

nBlock = 200;
read_index_list = 1:nBlock:vobj.NumberOfFrames;
if read_index_list(end) ~= vobj.NumberOfFrames
    read_index_list = [read_index_list vobj.NumberOfFrames+1];
end

for iB = 1:(length(read_index_list) - 1)
    tic
    read_index = [read_index_list(iB) read_index_list(iB+1)-1];
    fprintf(1, 'Processing %d / %d (%.1f%%)\n', read_index(1), vobj.NumberOfFrames, read_index(1)/vobj.NumberOfFrames*100);
    eye_images = read(vobj, read_index);
    
    tempArea = nan(size(eye_images,4),1);
    tempE = nan(size(eye_images,4),1);
    brightness = nan(size(eye_images,4),1);
    
    parfor iF = 1:size(eye_images,4) % extracting eye area etc.
        snapshot = eye_images(:,:,1,iF);
        [tempArea(iF),tempE(iF)]= eye_tracking(snapshot, THRES_eye,se_eye);
        brightness(iF) = mean(mean(snapshot));
    end
    eye_area(read_index(1):read_index(2)) = tempArea;
    eye_ect(read_index(1):read_index(2)) = tempE;
    eye_brightness(read_index(1):read_index(2)) = brightness;
    
    % save sample images    
    if mod(iB,10) == 1
        eye_tracking(eye_images(:,:,1,1), THRES_eye,se_eye,1);
        saveas(gcf,[saveFolder 'eye_test' num2str(iB) '.jpg'])
        close all;
    end
    toc
end

save( [saveFolder 'data.mat'],'eye_area','eye_ect','eye_brightness','frame_rate','THRES_eye','THRES_pupil')
end

