% input:
% grayEyeImg: each pixel value in the image
% threshold: threshold of binalizing the image
% se: element for morphological opening to remove spiky edges in the image
% plotflag: 1, create a figure

function [eye_area, eccentricity, brightness]= eye_tracking(grayEyeImg, threshold, se, plotflag)
%%
if nargin < 4
    plotflag = 0;
end
if plotflag
    figure;
    subplot(3,1,1); imshow(grayEyeImg)
end
try
    maskedImage = ~im2bw(grayEyeImg, threshold/255);
    maskedImage = bwareaopen(maskedImage,500); % remove small noise areas left
    if plotflag
        subplot(3,1,2); imshow(maskedImage)
    end

    maskedImage = imopen(maskedImage,se); % remove bright spots on eye 
    final_image = imfill(bwareaopen(maskedImage,500),'holes'); % remove small noise areas left

    r_stats = regionprops(final_image,{'Area','Eccentricity','Image'});
    [~,idx] = max([r_stats.Area]);
    r_stats = r_stats(idx); % only keep the largest 2
    eye_area = r_stats.Area;
    eccentricity = r_stats.Eccentricity;
    if plotflag
        subplot(3,1,3); imshow(r_stats.Image)
    end
    
    brightness = mean(mean(grayEyeImg));

catch
    eye_area = nan;
    eccentricity = nan;
    brightness = nan;
end