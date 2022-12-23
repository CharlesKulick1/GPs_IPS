MVAL = 3; % obsInfo.M
PROBLEM_NAME = "FM"; %CSF, AD, or FM
VERBOSE_RESULTS = true; %print hyperparameters, errors, times etc.
LearnBasisHyps = false; %learn the hyperparameters 1-4 for Matern basis


%Adjustable parameters.
CGErrorTol = 10^(-6);   %Error tolerance in the CG algorithm.
CG_ITER_LIMIT = 100;   %Max number of CG iterations.
mFORGLIK = CG_ITER_LIMIT;   %Number of test vectors for Lanczos.
lFORGLIK = CG_ITER_LIMIT;   %Number of CG iters from Lanczos.
rangeOfI = 100;   %Size of preconditioner. If wanting dynamic size, move down to inner loop.
jitter = 10^(-4);   %Value to use for sigma if sigma is too small.
HVAL = 10^(5);   %NOT USED.
GlikRuns = 100;   %Runs of minimizing.
alpha = 1.0;  %Range of randomness in intialization of hyps.
nT = 1;     %Number of trials.



%Datagen code.
%File name where data is stored.
addpaths;
fullname = strcat(PROBLEM_NAME, strcat("20_L5_M",num2str(MVAL)));

if isfile(strcat(fullname,".mat"))

     % File exists.
     load(fullname);
     fprintf('\n Using previously generated data ......');

else

     % File does not exist.
     fprintf('\n No such file. Generating new data ......');
     if strcmp(PROBLEM_NAME, "CSF")
         Example = CSF_def();
     elseif strcmp(PROBLEM_NAME, "AD")
         Example = AD_def();
     elseif strcmp(PROBLEM_NAME, "FM")
         Example = FM_def();
     else
         fprintf('\n Unknown problem name identifier.');
         %quit
     end

sysInfo                        = Example.sysInfo;
solverInfo                     = Example.solverInfo;
obsInfo                        = Example.obsInfo;    
obsInfo.MrhoT = 1;
obsInfo.M = MVAL; % # trajectories with random initial conditions for learning interaction kernel
saveON= 0;
plotON = 0;
learnInfo.rhoLT = Generate_rhoT(sysInfo,obsInfo,solverInfo,saveON,plotON);% empirical pairwise distance

if obsInfo.obs_noise>0
  obsInfo.use_derivative     = true;
end

learnInfo.N = sysInfo.N;
learnInfo.d = sysInfo.d;
learnInfo.order = sysInfo.ode_order;
learnInfo.name = sysInfo.name;
learnInfo.jitter = 1e-6;
learnInfo.Cov = 'Matern';
learnInfo.dtraj ='false'; % do not compute dtraj during trajectory computation

Nsub = learnInfo.N;
sub = 1:learnInfo.N;
dN1 = learnInfo.d*learnInfo.N;
dNs = learnInfo.d*Nsub;

learnInfo.v = 5/2;

name = learnInfo.name;

if strcmp(name,"FM") | strcmp(name,"CSF")
    learnInfo.hyp0 = log([rand(1,7)]);
else
    learnInfo.hyp0 = log([rand(1,5)]);
end

[dxpath_test,xpath_test,dxpath_train, xpath_train]=Generate_training_data(sysInfo,obsInfo,solverInfo);
learnInfo.rho_emp = rho_empirical(xpath_train,sysInfo,obsInfo,saveON,plotON);% empirical pairwise distance 
dxpath_train= trajUnifNoiseAdditive(dxpath_train, obsInfo.obs_noise);

X_train=[];
Y_train=[];


for i = 1:obsInfo.M
    for j = 1:size(xpath_train,2)
        X_train = [X_train;xpath_train(:,j,i)];
        if sysInfo.ode_order ==2
            Y_train = [Y_train;dxpath_train(sysInfo.d*sysInfo.N+1:end,j,i)];
        else
            Y_train = [Y_train;dxpath_train(:,j,i)];
        end
    end
end

learnInfo.L= size(xpath_train,2)*size(xpath_train,3);
learnInfo.X = X_train;
learnInfo.Y = Y_train;

learnInfo.xpath_train = xpath_train;
learnInfo.dxpath_train = dxpath_train;

learnInfo.hyp = learnInfo.hyp0;   

save(fullname);

fprintf('\n Done generating! Begin to learn ......');

end


%Now, data has been loaded. Run the standard learning.


%Enter method to use for greatest likelihood.
GlikMethod = @GlikGeneral;

%Preconditioner method.
PreconMethod = @RandomNystbackup2_Sui;

%Constants.
learnInfo.v = 5/2;
M = obsInfo.M;
LForDecomp = obsInfo.L;
n = learnInfo.N;
D = learnInfo.d;
name = learnInfo.name;

%Decomp for decompositon.
data = learnInfo.xpath_train(1:D*n,:,:);
dataA = learnInfo.xpath_train(D*n+1:2*D*n,:,:);

%Result storage containers.
errorphis = zeros(4,nT);      %store errors of phis in L-infinity and L2rhoT norms
errortrajs_train = zeros(4,nT);     %store mean and std of trajectory error in training data
errortrajs_test = zeros(4,nT);      %store mean and std of trajectory error in testing data
hypparameters = zeros(length(learnInfo.hyp0),nT);   %store estimated hyperparameters
errorhyp = zeros(3,nT);      %store hyperparameter errors
runtimes = zeros(4,nT);      %store runtimes of each section
hyp_errors_rel = zeros(3,nT);      %store hyperparameter errors
hyp_errors_abs = zeros(3,nT);      %store hyperparameter errors


for k = 1 : nT

    %These are guesses for hyperparameters so we can center
    %intitialization values for the learned hyperparameters.
    originalHyps = 0 * learnInfo.hyp0;
    originalHyps(5) = log(obsInfo.obs_noise);
    originalHyps(5) = originalHyps(5) + alpha * (2 * rand(1,1) - 1);

    if strcmp(name,"FM")
        originalHyps(6) = log(1.5);
        originalHyps(7) = log(0.5);
        originalHyps(6) = originalHyps(6) + alpha * (2 * rand(1,1) - 1);
        originalHyps(7) = originalHyps(7) + alpha * (2 * rand(1,1) - 1);
    elseif strcmp(name,"CSF")
        originalHyps(6) = log(1);
        originalHyps(7) = log(2);
        originalHyps(6) = originalHyps(6) + alpha * (2 * rand(1,1) - 1);
        originalHyps(7) = originalHyps(7) + alpha * (2 * rand(1,1) - 1);
    end

    learnInfo.hyp = originalHyps;

    %Get constants from hyperparameters.
    deltaE = exp(learnInfo.hyp(1));
    omegaE = exp(learnInfo.hyp(2));
    deltaA = exp(learnInfo.hyp(3));
    omegaA = exp(learnInfo.hyp(4));
    sigma = exp(learnInfo.hyp(5))^2;
    
    %If sigma is NaN, there is no noise. Use jitter factor.
    if isnan(sigma)
        sigma = jitter;
    end

    %Time a single run of Greatest Likelihood.
    tic;
    [fval2, dfval2,~] = GlikMethod(learnInfo, learnInfo.hyp, mFORGLIK, lFORGLIK, CGErrorTol, HVAL, M, rangeOfI, PreconMethod, LearnBasisHyps)
    runtimes(1,k) = toc;

    
    %Reset and run the actual optimization.
    learnInfo.hyp = originalHyps;
    [fval, dfval,~] = GlikMethod(learnInfo, learnInfo.hyp, mFORGLIK, lFORGLIK, CGErrorTol, HVAL, M, rangeOfI, PreconMethod, LearnBasisHyps);
    Glik_hyp = @(hyp)GlikMethod(learnInfo, hyp, mFORGLIK, lFORGLIK, CGErrorTol, HVAL, M, rangeOfI, PreconMethod, LearnBasisHyps);
    [learnInfo.hyp,flik,i] = minimize(learnInfo.hyp, Glik_hyp, -GlikRuns);
    runtimes(2,k) = toc;

    %Reset to default hyps for basis.
    learnInfo.hyp(1:4) = [0,0,0,0];

    hyp_errors_rel(1,k) = abs(exp(learnInfo.hyp(5))^2 - obsInfo.obs_noise^2) / abs(obsInfo.obs_noise^2);
    hyp_errors_abs(1,k) = abs(exp(learnInfo.hyp(5))^2 - obsInfo.obs_noise^2);


    if strcmp(name,"CSF")
        hyp_errors_rel(2,k) = abs(exp(learnInfo.hyp(6)) - 1) / abs(1);
        hyp_errors_rel(3,k) = abs(exp(learnInfo.hyp(7)) - 2) / abs(2);
        hyp_errors_abs(2,k) = abs(exp(learnInfo.hyp(6)) - 1);
        hyp_errors_abs(3,k) = abs(exp(learnInfo.hyp(7)) - 2);
    elseif strcmp(name,"FM")
        hyp_errors_rel(2,k) = abs(exp(learnInfo.hyp(6)) - 0.5) / abs(0.5);
        hyp_errors_rel(3,k) = abs(exp(learnInfo.hyp(7)) - 1.5) / abs(1.5);
        hyp_errors_abs(2,k) = abs(exp(learnInfo.hyp(6)) - 0.5);
        hyp_errors_abs(3,k) = abs(exp(learnInfo.hyp(7)) - 1.5);
    end


    %If accelerated, then we only need Ym to predict.
    learnInfo.option = 'alldata';
    learnInfo = GetYm(learnInfo,learnInfo.hyp);
    
    %Set final hyperparameters.   
    hypparameters(:,k) = exp(learnInfo.hyp);
    deltaE = exp(learnInfo.hyp(1));
    omegaE = exp(learnInfo.hyp(2));
    deltaA = exp(learnInfo.hyp(3));
    omegaA = exp(learnInfo.hyp(4));
    sigma = exp(learnInfo.hyp(5))^2;
    
    %If sigma is NaN, there is no noise. Still use jitter factor.
    if isnan(sigma)
        sigma = jitter;
    end
    
    
    X = learnInfo.X;
    dN = learnInfo.d*learnInfo.N*learnInfo.order;
    L = length(X)/dN;
    LForDecomp = L / M;
    
    %Decompose for the final kernel methods for prediction.
    KE = TotalDecompForDebug52(data, data, omegaE, deltaE, n, D, M, LForDecomp); 
    MultByKE = @(x) KE * x;
    
    KA = TotalDecompForDebug52(data, dataA, omegaA, deltaA, n, D, M, LForDecomp);
    MultByKA = @(x) KA * x;

    %Now, we have our explicit kernel. Given a preconditioner preference,
    %we call it to create P such that || (P+sigmaI)^-1 - (K+sigmaI)^-1 ||
    %small.    
    [~, PreConInvRaw] = PreconMethod(learnInfo, LForDecomp, M, rangeOfI, jitter, KE, KA, sigma);
    PreConInv = @(x) PreConInvRaw * x;

    %Multiply by K + sigmaI.
    MultByWholeK = @(x) MultByKE(x) + MultByKA(x) + sigma*x;
    
    %Multiply by entire (K+sigmaI)^-1.
    multByKInv = @(x) StandardPCG(MultByWholeK, x, PreConInv, CGErrorTol, lFORGLIK);
    
    %Matrix multiplication.
    multMatByKInv = @(X) RunCGOnMatrixInitGuesser(MultByWholeK, X, PreConInv, CGErrorTol, CG_ITER_LIMIT);
    
    learnInfo.invKTimesYm = multByKInv(learnInfo.Ym);

    %Visualize kernel.
    visualize_phis_CG(sysInfo,obsInfo,learnInfo,'E', multMatByKInv);
    visualize_phis_CG(sysInfo,obsInfo,learnInfo,'A', multMatByKInv);
    runtimes(3,k) = toc;
    
    
    %Calculate errors.
    range = [0, learnInfo.rhoLT.edges(max(find(learnInfo.rhoLT.rdens~=0)))];
    [learnInfo, errorphis(1,k),errorphis(2,k)] = errornorms_phis_CG(sysInfo,obsInfo,learnInfo,range,'E', multMatByKInv);
    [learnInfo, errorphis(3,k),errorphis(4,k)] = errornorms_phis_CG(sysInfo,obsInfo,learnInfo,range,'A', multMatByKInv);
    result_train = construct_and_compute_traj(sysInfo,obsInfo,solverInfo,learnInfo, learnInfo.xpath_train(:,1,:));
    errortrajs_train(:,k) = [result_train.train_traj_error result_train.prediction_traj_error]';
    result_test = construct_and_compute_traj(sysInfo,obsInfo,solverInfo,learnInfo,sysInfo.mu0());
    errortrajs_test(:,k) = [result_test.train_traj_error result_test.prediction_traj_error]';
    runtimes(4,k) = toc;


    %Save file.
    filename = strcat(PROBLEM_NAME, strcat("_ITER",num2str(MVAL)));
    save(filename);

end


if VERBOSE_RESULTS

    %Print results for ease of use.
    runtimes
    
    avgtime = zeros(4,1);
    stdtime = zeros(4,1);
    
    for i = 1 : 4
        avgtime(i,1) = mean(runtimes(i,:));
        stdtime(i,1) = std(runtimes(i,:));
    end
    
    avgtime
    stdtime
    
    avgkerror = zeros(4,1);
    stdkerror = zeros(4,1);
    avgetrain = zeros(4,1);
    stdetrain = zeros(4,1);
    avgetest = zeros(4,1);
    stdetest = zeros(4,1);
    
    for i = 1 : 4
        avgkerror(i,1) = mean(errorphis(i,:));
        stdkerror(i,1) = std(errorphis(i,:));
        avgetrain(i,1) = mean(errortrajs_train(i,:));
        stdetrain(i,1) = std(errortrajs_train(i,:));
        avgetest(i,1) = mean(errortrajs_test(i,:));
        stdetest(i,1) = std(errortrajs_test(i,:));
    end
    
    
    hypparameters
    
    hyp_errors_rel
    hyp_errors_abs
    
    Zav_rel_error = zeros(3,1);
    Zav_abs_error = zeros(3,1);
    Zstd_rel_error = zeros(3,1);
    Zstd_abs_error = zeros(3,1);
    
    for i = 1 : 3
        Zav_rel_error(i,1) = mean(hyp_errors_rel(i,:));
        Zstd_rel_error(i,1) = std(hyp_errors_rel(i,:));
        Zav_abs_error(i,1) = mean(hyp_errors_abs(i,:));
        Zstd_abs_error(i,1) = std(hyp_errors_abs(i,:));
    end

end

%Save final report.
filename = strcat(PROBLEM_NAME, strcat("_RESULT",num2str(MVAL)));
save(filename);





