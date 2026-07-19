function [X_sol, E_sol, exitflag, fval] = SolveQuadrupedalZE( X0, E0, Para, Constraints )
% SolveQuadrupedalZE  Solve for state X and event-timings E such that
%                     Quadrupedal_ZeroFun_v2_test(X,E,Para,Constraints) == 0
%
% [X_sol, E_sol, exitflag, fval] = SolveQuadrupedalZE( X0, E0, Para, Constraints )
%
% Inputs:
%   X0          1×13 initial guess for state vector
%   E0          1×9  initial guess for event timings
%   Para        1×7  parameters [k, ks, J, lb, l, …]
%   Constraints optional cell array of pairs, e.g. {'(BL,BR)'}
%
% Outputs:
%   X_sol       1×13 solved state vector
%   E_sol       1×9  solved event‐timings
%   exitflag    fsolve exit flag
%   fval        final residual vector (should be ~0)

    if nargin<4, Constraints = {}; end

    % pack initial guess
    z0 = [ X0(:); E0(:) ];   %# 22×1

    % fsolve options
    opts = optimset( ...
      'Algorithm','levenberg-marquardt', ...
      'Display','iter', ...
      'MaxFunEvals',15000, ...
      'MaxIter',3000, ...
      'TolFun',1e-9, ...
      'TolX',1e-12 );

    % objective: call the _test entry‐point with skipSolve so we don't
    % re‐invoke the inner E‐solver on every trial
    fun = @(z) Quadrupedal_ZeroFun_v2_test( ...
                   z(1:13)', ...        % X
                   z(14:22)', ...       % E
                   Para, Constraints, ... 
                   'skipSolve' );       % flag to bypass enforce‐once

    % run fsolve
    [z_sol, fval, exitflag] = fsolve( fun, z0, opts );

    % unpack solution
    X_sol = z_sol(1:13).';
    E_sol = z_sol(14:22).';

end
