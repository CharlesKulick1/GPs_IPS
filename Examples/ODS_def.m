function Example = ODS_def()
% Define associated terms for OPINION DYNAMICS Continuous

% (c) XXXX

% System
sysInfo.name            = 'ODS';                                                   % name of the dynamics
sysInfo.d               = 1;                                                                       % dimension for the state vector (in this case, opinion vector)
sysInfo.N               = 10;                                                                      % # of agents
sysInfo.Ns              = 3;                                                                       % # of stubborn agents
sysInfo.phi            = {@(r)ODS_influence(r, 3), @(x,i) ODS_ctr(x,i,sysInfo.Ns)};                                               % energy based interaction
sysInfo.K               = 1;                                                                       % # of types
sysInfo.ode_order       = 1;                                                                       % order of the ODE system
sysInfo.type_info       = ones(1, sysInfo.N);                                                     % function mapping agent index to its type index
sysInfo.RE              = [];                                                                      % energy based reulation on interactoin beween agent i and agent i'

sysInfo.mu0             = @() ODS_init_config(sysInfo.d, sysInfo.N, sysInfo.d);                           % distribution of initial conditions
sysInfo.T_f             = 20;                                                                      % final time the system will reach steady state
sysInfo.domain          = [0, 10];
sysInfo.type = 1;
sysInfo.type_info = ones(sysInfo.N,1);
% ODE solver
solverInfo.time_span    = [0, sysInfo.T_f];                                                       % put it into the time_span vector, always starting from 0
solverInfo.option = odeset('RelTol',1e-5,'AbsTol',1e-6);

% Observations
obsInfo.M               = 3;                                                                      % # trajectories with random initial conditions for learning interaction kernel
obsInfo.L = 4;
obsInfo.time_vec = 0:5:15;
% Observations will be up to this time
obsInfo.use_derivative  = true;                                                                   % indicator of the availability of derivative data
obsInfo.obs_noise       = 0.05;
obsInfo.mu_trajnoise    = @(traj,sigma) trajUnifNoiseAdditive( traj, sigma );
obsInfo.rho_T_histedges    = linspace(0,sysInfo.domain(2),1000);  % a rather arbitrary set of bins to track estimators of \rho^L_T


% package the data
Example.sysInfo         = sysInfo;
Example.solverInfo      = solverInfo;
Example.obsInfo         = obsInfo;


end