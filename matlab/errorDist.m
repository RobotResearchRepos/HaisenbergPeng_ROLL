clc;
clear;
close all
folder = "/media/haisenberg/BIGLUCK/Datasets/NCLT/datasets/fastlio_fusion";
% folder = "/media/haisenberg/BIGLUCK/Datasets/NCLT/datasets/updated_map_newInlier";
date = "2013-02-23";
logFilePath = folder+"/"+date+"/map_pcd/mappingError.txt";
poseFilePath = folder+"/"+date+"/map_pcd/path_mapping.txt";
% poseFilePath = folder+"/"+date+"/map_pcd/path_fusion.txt";
gtFilePath = "/media/haisenberg/BIGLUCK/Datasets/NCLT/datasets/"+date+"/groundtruth_"+date+".csv";

%% log file reading
fID = fopen(logFilePath);
strPattern = "";
n = 11;
for i=1:n
    strPattern = strPattern+"%f";
end
logData = textscan(fID,strPattern);
timeLog = logData{1}-logData{1}(1);
regiError = logData{5};
inlierRatio2 = logData{4};
inlierRatio = logData{3};
isTMM = logData{2};

%% pose file reading
fID2 = fopen(poseFilePath);
strPattern = "";
n = 7;
for i=1:n
    strPattern = strPattern+"%f";
end
poseData = textscan(fID2,strPattern);
lenPose = length(poseData{1});
matPose = zeros(lenPose,7);
for i=1:lenPose
    for j=1:7
        matPose(i,j) = poseData{j}(i);
    end
end

%% gt reading
% readcsv readmatrix:sth is wrong
fID3 = fopen(gtFilePath);
gtData = textscan(fID3, "%f%s%f%s%f%s%f%s%f%s%f%s%f");
% downsample
downsample = 10;
lenGT = length(gtData{1});
matGT = zeros(floor(lenGT/10),7);
%% kloam+fastlio uses imu pose, so here convert body pose to imu pose
tbi = [-0.11 -0.18 -0.71]';
for i=1:floor(lenGT/10)
    for j=1:7
        matGT(i,j) = gtData{2*j-1}(10*i);
    end
    Rmb = eul2rotm([ matGT(i,7),matGT(i,6),matGT(i,5)],"ZYX");
    tmb = matGT(i,2:4)';
    tmi = Rmb*tbi +tmb;
    matGT(i,2:4) = tmi';
end

%% sync with time
timeGT = matGT(:,1)/1e+6; % us -> sec
timePose =  matPose(:,1)/1e+6;
MDtimeGT = KDTreeSearcher(timeGT);
[idx, D] = rangesearch(MDtimeGT,timePose,0.05);
ateError = zeros(lenPose,1);
not_found = 0;

for i=1:lenPose
    if isempty(idx{i})
        not_found = not_found + 1;
        continue;    
    end
        %% rule out obvious wrong ground truth
    if date=="2013-02-23" && matPose(i,2)>-310 && matPose(i,2)<-260&&...
        matPose(i,3)>-450 && matPose(i,3)<-435
        continue;
    end
    %% convert gt body to gt imu
    ateError(i) = norm(matPose(i,2:3)-matGT(idx{i}(1),2:3));
end
idxOver1m = find(ateError> 1.0);
%% PLOT
figure(1)
plot(timeLog,isTMM);
hold on
plot(timeLog,inlierRatio2);
plot(timeLog,inlierRatio);
plot(timeLog,regiError);
plot(timePose-timePose(1),ateError);
legend("isTMM","inlierRatio1.0","inlierRatio0.1","average reproj. error","loc. error");
xlabel("Time (sec)");
ylabel("Absolute trajectory error (m)");
% saveas(1,date + "_ate_error.jpg");


figure(2)
% plot(matPose(:,2),matPose(:,3),".");
plot(matPose(:,2),matPose(:,3));
hold on
plot(matGT(:,2),matGT(:,3));
plot(matPose(idxOver1m,2),matPose(idxOver1m,3),"*");

figure(3)
plot(timeLog,logData{7});
hold on
plot(timeLog,logData{8});
plot(timeLog,logData{9});
plot(timeLog,logData{10});
legend("x","y","xF","yF");

figure(4)
histogram(ateError);

% a=[timePose-timePose(1) ateError];