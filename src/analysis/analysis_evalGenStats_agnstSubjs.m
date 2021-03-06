%% clear stuff

clc
clearvars

%% load the necessary data

config_file='config_template.m';
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
addpath(strcat(pwd,'/config'))
run(config_file);

% loadName = strcat(OUTPUT_DIR, '/processed/', OUTPUT_STR, '_fit_wsbm_script_v7p3.mat');
% load(loadName) ;

loadName = strcat(OUTPUT_DIR, '/interim/', OUTPUT_STR, '_templateModel_1.mat');
load(loadName) ;

loadName = strcat(OUTPUT_DIR, '/interim/', OUTPUT_STR, '_comVecs.mat');
load(loadName) ;

loadName = strcat(OUTPUT_DIR, '/processed/', OUTPUT_STR, '_basicData_v7p3.mat');
load(loadName) ;

FIGURE_NAME = 'figC2' ;

outputdir = strcat(PROJECT_DIR,'/reports/figures/',FIGURE_NAME,'/');
mkdir(outputdir)

%% actual data

templateAdj = templateModel.Data.Raw_Data ;
templateAdj(~~isnan(templateAdj)) = 0 ;

%% and the modular model 

muMod = dummyvar(comVecs.mod)' ;
[~,modularityModel] = wsbm(templateModel.Data.Raw_Data, ...
    templateModel.R_Struct.R, ...
    'W_Distr', templateModel.W_Distr, ...
    'E_Distr', templateModel.E_Distr, ...
    'alpha', templateModel.Options.alpha, ...
    'mu_0', muMod , ...
    'verbosity', 0);

% tmpYeo = CBIG_HungarianClusterMatch(comVecs.wsbm,comVecs.yeo) ;
% muYeo = dummyvar(tmpYeo)' ;
% muYeo = muYeo(sum(muYeo,2)>0,:) ;
% 
% [~,yeoModel] = wsbm(templateModel.Data.Raw_Data, ...
%     sym_RStruct(7), ...
%     'W_Distr', templateModel.W_Distr, ...
%     'E_Distr', templateModel.E_Distr, ...
%     'alpha', templateModel.Options.alpha, ...
%     'mu_0', muYeo , ...
%     'verbosity', 0);

%% try out the evalWSBM code

nNodes = templateModel.Data.n ;

youngAdult_data = dataStruct(datasetDemo.age > ageLowLim & datasetDemo.age <= ageHighLim) ;
[a,b,avgTemp_dist] = make_template_mat(youngAdult_data, ...
    LEFT_HEMI_NODES, ...
    RIGHT_HEMI_NODES, ...
    MASK_THR_INIT) ; 

% actually replace the 0's with NaN
%avgTemp(avgTemp == 0) = NaN ;
avgTemp_dist = avgTemp_dist(selectNodesFrmRaw,selectNodesFrmRaw);
% clear diagonal
avgTemp_dist(1:nNodes+1:end)=0; 

%% the whole dataset!

subjDataMat = zeros([ nNodes nNodes length(dataStruct) ]);
for idx = 1:length(dataStruct)  

    tmpAdj = dataStruct(idx).countVolNormMat(selectNodesFrmRaw, selectNodesFrmRaw);
    % get rid of the diagonal
    %n=size(tmpAdj,1);
    tmpAdj(1:nNodes+1:end) = 0; 
    % mask out AdjMat entries below mask_thr
    tmpAdj_mask = dataStruct(idx).countMat(selectNodesFrmRaw, selectNodesFrmRaw) > MASK_THR ;    
    tmpAdj_mask(tmpAdj_mask > 0) = 1 ;   
    tmpAdj = tmpAdj .* tmpAdj_mask ;
    tmpAdj(isnan(tmpAdj)) = 0 ;
    subjDataMat(:,:,idx) = tmpAdj ;
end

%% eval gen call

% setup some structs to record results
eval_subj_wsbm_K = cell([ length(dataStruct)  1]);
eval_subj_mod_K = cell([ length(dataStruct)  1]);

parallel_pool = gcp ; 
ppm1 = ParforProgMon('subjs',length(dataStruct),1) ;
parfor idx = 1:length(dataStruct)  
    
    currentSubj = subjDataMat(:,:,idx) ;
    
    % function [B,E,K] = eval_genWsbm_model(wsbmModel,D,numSims)]
    %           B,          n x n x numSims matrix of synthetic networks
    %           E,          energy for each synthetic network
    %           K,          Kolmogorov-Smirnov statistics for each synthetic
    %                       network.

    [~,~,eval_subj_wsbm_K{idx}] = eval_genWsbm_model1_agnstSubj(templateModel,avgTemp_dist,5000,0,currentSubj);
    [~,~,eval_subj_mod_K{idx}] = eval_genWsbm_model1_agnstSubj(modularityModel,avgTemp_dist,5000,0,currentSubj);

    %disp(idx)
    ppm1.increment() 

    
end

%% results across subjects

wsbm_meanKS = cellfun(@(x) mean(x,2),eval_subj_wsbm_K,'UniformOutput',false) ;
% wsbm_bttm5 = cellfun(@(x) mean(x(x >= prctile(x,5))),wsbm_meanKS,'UniformOutput',true) ;

mod_meanKS = cellfun(@(x) mean(x,2),eval_subj_mod_K,'UniformOutput',false) ;
% mod_bttm5 = cellfun(@(x) mean(x(x >= prctile(x,5))),mod_meanKS,'UniformOutput',true) ;

wsbm_subj_means = cellfun(@(x) mean(mean(x,2)),eval_subj_wsbm_K,'UniformOutput',true) ;
mod_subj_means = cellfun(@(x) mean(mean(x,2)),eval_subj_mod_K,'UniformOutput',true) ;

%[a,b,c,d] = ttest2(wsbm_subj_means,mod_subj_means,'Vartype','unequal') 
[a,b,c,d] = ttest(wsbm_subj_means,mod_subj_means) 

mean(wsbm_subj_means)
std(wsbm_subj_means)
mean(mod_subj_means)
std(mod_subj_means)


% = cellfun(@(x) median(mean(x,2)),eval_subj_wsbm_K,'UniformOutput',true) ;
% ttt = cellfun(@(x) median(mean(x,2)),eval_subj_wsbm_K,'UniformOutput',true) ;




%% collate results

eval_subj_wsbm_K_mat = cell2mat(eval_subj_wsbm_K) ;
eval_subj_mod_K_mat = cell2mat(eval_subj_mod_K) ;

histogram(mean(eval_subj_wsbm_K_mat,2))
hold
histogram(mean(eval_subj_mod_K_mat,2))

% also compare histograms between each 53 subject
for idx = 1:length(youngAdult_data)
    
    subj_diff(idx) = median(mean(eval_subj_wsbm_K{idx},2)) - ...
        median(mean(eval_subj_mod_K{idx},2)) ;

end


figure 
hold
for idx =1:length(youngAdult_data)

    histogram(mean(eval_subj_wsbm_K{idx},2));   
end

figure 
hold
for idx =1:length(youngAdult_data)

    histogram(mean(eval_subj_mod_K{idx},2));   
end

%% but also how to display this...?

% load(strcat(PROJECT_DIR,'/data/processed/',OUTPUT_STR,'_evalGenReps_subj.mat'))
save(strcat(PROJECT_DIR,'/data/processed/',OUTPUT_STR,'_evalGenReps_subj.mat'),...
    'eval_subj_wsbm_K',...
    'eval_subj_mod_K' ...
     )










