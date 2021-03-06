clear, clc, close all

git = getGitInfo();
git = git.hash(1:6);
notes = '';

%% Params
dataset_name = 'dota';
f = samplerReal(dataset_name);
n_resamples_per_trial = 10000;
n_trials_per_corruption_level = 10;  % each trial is subset of total bootstrap, mostly for convergence plots
nprocesses = 2;
n_resamples_per_corruption_level = n_resamples_per_trial*n_trials_per_corruption_level;  % number of bootstrap iterations per corruption level
p0 = 0.1;  % natural corruption (dist1 samples in training)
p_max = 1.0;  % maximum artificial corruption to inject (including p_0)
nV = 100;

% Choose training set size directly
nT = 100; %10000;
p_clean_resample = (1-p0)^nT;

n_corruption_levels = 10;%2*nT;

p = linspace(p0, p_max, n_corruption_levels);
B = NaN(length(p), n_trials_per_corruption_level);

pool = gcp('nocreate'); % If no pool, do not create new one.
if isempty(pool)
    poolsize = 0;
else
    poolsize = pool.NumWorkers;
end
if poolsize ~= nprocesses
    if poolsize > 0
        delete(pool)
    end
    parpool(nprocesses);
end

filename = ['AB_', datestr(now, 'yyyy-mm-dd_hh-MM-ss'), '_', git, '_', dataset_name, '_nT', num2str(nT), '_p0', num2str(p0), '_K', num2str(n_resamples_per_corruption_level), '.mat']

tic;
parfor i = 1:length(p)
    p_i = p(i);
    D = makedist('Binomial','N',nT,'p',p_i);
    A(i,:) = D.pdf(0:nT);
    btrials = zeros(1, n_trials_per_corruption_level);
    for j = 1:n_trials_per_corruption_level
        b_jk = 0;
        for k = 1:n_resamples_per_trial
            n1 = binornd(nT, p_i);
            n0 = nT - n1;
            [x, y, xtest, ytest] = f.sample_dual(n0, nT, 0, nV);
            SVMModel = fitcsvm(x, y);
            yhat = predict(SVMModel, xtest);
            error = 1 - sum(strcmp(yhat, ytest))/length(ytest);
            b_jk = b_jk+error;
        end
        btrials(j) = b_jk/n_resamples_per_trial;
    end
    B(i, :) = btrials;
end
b3_time = toc; tic;
fprintf('B3 sampling time: %f sec \n', b3_time);

%% Compute s_true
% Compute s_true, at most 50 points
s_true_n_corrupted_samples = floor(linspace(0, nT, min(50, nT+1)));
s_true = zeros(length(s_true_n_corrupted_samples), n_trials_per_corruption_level);

%% Compute very accurate estimate of s_true at p=0
tic
parfor i = 1:n_trials_per_corruption_level
    for j = 1:n_resamples_per_corruption_level
        [x, y, xtest, ytest] = f.sample_dual(nT, nT, 0, nV);
        SVMModel = fitcsvm(x, y);
        yhat = predict(SVMModel, xtest);
        error = 1 - sum(strcmp(yhat, ytest))/length(ytest);
        s_true(1, i) = s_true(1, i) + error/n_resamples_per_corruption_level;
    end
end
s_true_time = toc;
fprintf('True error sampling time at p=0: %f sec \n', s_true_time);

save(filename, 'dataset_name', 'n_corruption_levels', 'n_trials_per_corruption_level', 'n_resamples_per_trial', 'n_resamples_per_corruption_level', 'B', 'nT', 'nV', 's_true', 's_true_n_corrupted_samples', 'p0', 'p', 'nprocesses', 'b3_time', 's_true_time', 'notes', 'git')

%% Compute s_true at other corruption values
parfor i = 2:length(s_true)
    n_corrupted_samples = s_true_n_corrupted_samples(i);
    for j = 1:n_trials_per_corruption_level
        for k = 1:n_resamples_per_trial
            [x, y, xtest, ytest] = f.sample_dual(nT-n_corrupted_samples, nT, 0, nV);
            SVMModel = fitcsvm(x, y);
            yhat = predict(SVMModel, xtest);
            error = 1 - sum(strcmp(yhat, ytest))/length(ytest);
            s_true(i, j) = s_true(i, j)+error/n_resamples_per_trial;
        end
    end
end
s_true_time = toc;
fprintf('Total true error sampling time: %f sec \n', s_true_time);

save(filename, 'dataset_name', 'n_corruption_levels', 'n_trials_per_corruption_level', 'n_resamples_per_trial', 'n_resamples_per_corruption_level', 'B', 'nT', 'nV', 's_true', 's_true_n_corrupted_samples', 'p0', 'p', 'nprocesses', 'b3_time', 's_true_time', 'notes', 'git')