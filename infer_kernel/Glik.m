function [fval, dfval,learnInfo] = Glik(learnInfo,hyp)

% input - X: training position data
%         Y: taining velocity data

% (c) XXXX

X = learnInfo.X;
Y = learnInfo.Y;
dN = learnInfo.d*learnInfo.N*learnInfo.order;
L = length(X)/dN;
d = learnInfo.d;
N = learnInfo.N;
K = zeros(L*d*N,L*d*N); % kernelmatrix


v = learnInfo.v;
order = learnInfo.order;
name = learnInfo.name;
dN1 = d*N;
dKs = zeros(L*dN1,L*dN1); %derivative w.r.t. logsigma
dKo = zeros(L*dN1,L*dN1); %derivative w.r.t. logomega


for i = 1:L
    [K((dN1*(i-1)+1):(dN1*i),(dN1*(i-1)+1):(dN1*i)), dKs((dN1*(i-1)+1):(dN1*i),(dN1*(i-1)+1):(dN1*i)),dKo((dN1*(i-1)+1):(dN1*i),(dN1*(i-1)+1):(dN1*i))] = k_phi_Matern(X((dN*(i-1)+1):(dN*i)),X((dN*(i-1)+1):(dN*i)),learnInfo.d,v,hyp(1:2),order,name);

    for j = i+1:L
        [K((dN1*(i-1)+1):(dN1*i),(dN1*(j-1)+1):(dN1*j)), dKs((dN1*(i-1)+1):(dN1*i),(dN1*(j-1)+1):(dN1*j)),dKo((dN1*(i-1)+1):(dN1*i),(dN1*(j-1)+1):(dN1*j))] = k_phi_Matern(X((dN*(i-1)+1):(dN*i)),X((dN*(j-1)+1):(dN*j)),learnInfo.d,v,hyp(1:2),order,name);
        K((dN1*(j-1)+1):(dN1*j),(dN1*(i-1)+1):(dN1*i)) = K((dN1*(i-1)+1):(dN1*i),(dN1*(j-1)+1):(dN1*j))';
        dKs((dN1*(j-1)+1):(dN1*j),(dN1*(i-1)+1):(dN1*i)) = dKs((dN1*(i-1)+1):(dN1*i),(dN1*(j-1)+1):(dN1*j))';
        dKo((dN1*(j-1)+1):(dN1*j),(dN1*(i-1)+1):(dN1*i)) = dKo((dN1*(i-1)+1):(dN1*i),(dN1*(j-1)+1):(dN1*j))';
    end
end



if size(hyp,2) >= 3 && ~isnan(hyp(3))

    lognoise = hyp(3); %noise of Y
    K = K + exp(lognoise)^2*eye(dN1*L);

else
    K = K + learnInfo.jitter*eye(L*dN1);
end


learnInfo.K =K;



% Cholesky factorisation
[R,p] = chol(K,'lower'); % K=R'*R
if p > 0
    fprintf(1,'Covariance is ill-conditioned\n');
end

if strcmp('ODS',name)
    Ym = Y;
    Ydk = 0*Y;
    YdPa = 0*Y;
    logk = hyp(4); % parameter in control term

    YdPb = 0*Y;
    YdPc = 0*Y;
    Pa = hyp(5); % parameter in control term
    Pb = hyp(6); % parameter in control term
    Pc = hyp(7); % parameter in control term
    for i = 1:L
        Ym((dN1*(i-1)+1):(dN1*(i-1)+d)) = Y((dN1*(i-1)+1):(dN1*(i-1)+d)) + exp(logk)*(X((dN1*(i-1)+1):(dN1*(i-1)+d)) - Pa);
        Ym((dN1*(i-1)+d+1):(dN1*(i-1)+2*d)) = Y((dN1*(i-1)+d+1):(dN1*(i-1)+2*d)) + exp(logk)*(X((dN1*(i-1)+d+1):(dN1*(i-1)+2*d)) - Pb);
        Ym((dN1*(i-1)+2*d+1):(dN1*(i-1)+3*d)) = Y((dN1*(i-1)+2*d+1):(dN1*(i-1)+3*d)) + exp(logk)*(X((dN1*(i-1)+2*d+1):(dN1*(i-1)+3*d)) - Pc);
        Ydk((dN1*(i-1)+1):(dN1*(i-1)+d)) = (X((dN1*(i-1)+1):(dN1*(i-1)+d)) - Pa)*exp(logk);
        Ydk((dN1*(i-1)+d+1):(dN1*(i-1)+2*d)) = (X((dN1*(i-1)+d+1):(dN1*(i-1)+2*d)) - Pb)*exp(logk);
        Ydk((dN1*(i-1)+2*d+1):(dN1*(i-1)+3*d)) = (X((dN1*(i-1)+2*d+1):(dN1*(i-1)+3*d)) - Pc)*exp(logk);
        YdPa((dN1*(i-1)+1):(dN1*(i-1)+d)) = -exp(logk);
        YdPb((dN1*(i-1)+d+1):(dN1*(i-1)+2*d)) = -exp(logk);
        YdPc((dN1*(i-1)+2*d+1):(dN1*(i-1)+3*d)) = -exp(logk);
    end

    learnInfo.Ym = Ym;
    alpha = R'\(R\Ym);
    fval = 0.5*Ym'*alpha + sum(log(diag(R))) + log(2*pi)*(dN1*L)/2;

    dfval = 0*hyp;

    Q =  R'\(R\eye(L*dN1)) - alpha*alpha';
    dfval(1) = sum(sum(Q.*dKs))/2;
    dfval(2) = sum(sum(Q.*dKo))/2;

    if ~isnan(hyp(3))
        dfval(3) = 2*exp(lognoise)^2*trace(Q)/2;
    else
        dfval(3) = 0;
    end

    dfval(4) = alpha'* Ydk;
    dfval(5) = alpha'* YdPa;
    dfval(6) = alpha'* YdPb;
    dfval(7) = alpha'* YdPc;


elseif strcmp('CSF',name)
    Ym = 0*Y;
    Yda = 0*Y;
    Ydb = 0*Y;
    loga = hyp(4); % parameter in noncollective force
    logb = hyp(5);
    for i = 1:L
        for j = 1:N
            Ym((dN1*(i-1)+1+d*(j-1)):(dN1*(i-1)+d*j)) = Y((dN1*(i-1)+1+d*(j-1)):(dN1*(i-1)+d*j)) - (exp(loga) * X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j))*(1- norm(X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j)),2)^exp(logb)));
            Yda((dN1*(i-1)+1+d*(j-1)):(dN1*(i-1)+d*j)) = - X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j))*(1- norm(X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j)),2)^exp(logb))*exp(loga);
            Ydb((dN1*(i-1)+1+d*(j-1)):(dN1*(i-1)+d*j)) = exp(loga) * X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j))*norm(X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j)),2)^exp(logb)*log(norm(X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j)),2))*exp(logb);

        end
    end
    learnInfo.Ym = Ym;
    alpha = R'\(R\Ym);
    fval = 0.5*Ym'*alpha + sum(log(diag(R))) + log(2*pi)*(dN1*L)/2;

    dfval = 0*hyp;

    Q =  R'\(R\eye(L*dN1)) - alpha*alpha';
    dfval(1) = sum(sum(Q.*dKs))/2;
    dfval(2) = sum(sum(Q.*dKo))/2;

    if ~isnan(hyp(3))
        dfval(3) = 2*exp(lognoise)^2*trace(Q)/2;
    else
        dfval(3) = 0;
    end

    dfval(4) = alpha'* Yda;
    dfval(5) = alpha'* Ydb;


elseif strcmp('FM',name)
    Ym = 0*Y;
    Yda = 0*Y;
    Ydb = 0*Y;
    loga = hyp(4); % parameter in noncollective force
    logb = hyp(5);
    for i = 1:L
        for j = 1:N
            Ym((dN1*(i-1)+1+d*(j-1)):(dN1*(i-1)+d*j)) = Y((dN1*(i-1)+1+d*(j-1)):(dN1*(i-1)+d*j)) - (exp(loga) - exp(logb)*sum(X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j)).^2))*X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j));
            Yda((dN1*(i-1)+1+d*(j-1)):(dN1*(i-1)+d*j)) = - X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j))*exp(loga);
            Ydb((dN1*(i-1)+1+d*(j-1)):(dN1*(i-1)+d*j)) = sum(X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j)).^2)*X((dN*(i-1)+1+dN1+d*(j-1)):(dN*(i-1)+dN1+d*j))*exp(logb);

        end
    end
    learnInfo.Ym = Ym;
    alpha = R'\(R\Ym);
    fval = 0.5*Ym'*alpha + sum(log(diag(R))) + log(2*pi)*(dN1*L)/2;

    dfval = 0*hyp;

    Q =  R'\(R\eye(L*dN1)) - alpha*alpha';
    dfval(1) = sum(sum(Q.*dKs))/2;
    dfval(2) = sum(sum(Q.*dKo))/2;

    if ~isnan(hyp(3))
        dfval(3) = 2*exp(lognoise)^2*trace(Q)/2;
    else
        dfval(3) = 0;
    end

    dfval(4) = alpha'* Yda;
    dfval(5) = alpha'* Ydb;


end

end



