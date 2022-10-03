function PreConInv = ConstructNystPreconNoKOrExtras(learnInfo, L, M, rangeOfI, jitter)

    n = learnInfo.N;
    D = learnInfo.d;
    K = zeros(n*D*rangeOfI, n*D*M*L);

    %Make Nyst parts here instead.
    for i = 1 : rangeOfI
        K((n*D*(i-1)+1):(n*D*i),:) = TrueKCols(learnInfo,learnInfo.hyp,i,jitter);
    end

    [R, Aplus] = NystNoK(K, n*D*rangeOfI);

    P = chol(Aplus,'lower'); % K=R*R'
    pinvFactor = pinv(P);
    pinvAplus = pinvFactor' * pinvFactor;


    %Get the inverse.
    lognoise = learnInfo.hyp(5); %noise of data
    sigma = exp(lognoise)^2;
    extraTerm = 0;
    %Test for NaN.
    if isnan(lognoise)
        %Set lognoise st sigma is jitter.
        sigma = 10^(-6);%TODO dont hardcode
        extraTerm = 0;

    end


    PreConInv = (1 / (sigma + extraTerm))*eye(n*D*M*L) - (1 / (sigma + extraTerm)^2)*R*pinv((pinvAplus + (1/(sigma + extraTerm)) * (R' * R)))*R';

 