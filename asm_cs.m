% A Practical ASM function
% Solve: z = 1/2x'Gx + c'x, s.t. Ax>b
% This is a version with constraints seletion, based on Gionata's idea
% 2015.12.21
% Yi DING
% Input:
% x: Primal Variables
% w: Working set
% Output:
% xStar: Optimal point
% zStar: Optimal objective function
% iterStar: Iteration count

function [xStar, zStar, iterStar, lpW, failFlag] = asm_cs(G,invG,c,A,b,x,w,maxIter,ny,nu,M,P)

[mc,ndec] = size(A);
iterStar = 0;
failFlag = 0;

% Give error if the initial point is infeasible!
if min(A*x-b) < -1e-6
    error('Infeasible initial point!');
end

% In case we only consider constraitns on u and y
consInfo = zeros(M+1,nu*2+ny*2);
consInfoNum = zeros(1,nu*2+ny*2);
% % In case we consider constraitns on delta_u, u and y
% consInfo = zeros(nu*M+1,nu*4+ny*2);
% consInfoNum = zeros(1,nu*4+ny*2);

hpW = [];       % High priority working set
lpW = [];       % Low priority working set

w = sort(w);

if ~isempty(w)     % Initial hpW and lpW if w is not empty
    for i = 1:length(w)
        indexCons = w(i);
        [consInfo,consInfoNum] = addToConsInfo(indexCons,consInfo,consInfoNum,nu,ny,M,P);
    end
    % Update hpW and lpW
    [hpW,lpW] = updatePW(consInfo,consInfoNum);
end

for i = 1:maxIter
    if i == maxIter
        disp('maxIter reached!');
        xStar = x;
        finalAS = w;
        failFlag = 1;
        %error('maxIter reached!');
    end
    
    iterStar = iterStar + 1;
    g = G*x+c;
    
    % Form Aw and bw based on working set
    setSize = length(w);
    Aw = zeros(setSize,ndec);
    bw = zeros(setSize,1);
    for j = 1:setSize
        Aw(j,:)  = A(w(j),:);
    end
    
    % Solve equality-constrained QP problems
    if setSize == ndec && det(Aw) > 0.000001
        p = zeros(ndec,1);
    else
        [p, ~, ~] = eqp(G,invG,g,Aw,bw,zeros(ndec,1),setSize);
    end
    
    if (isZero(p,1e-4) == 1)  % Check whether p_k is zero
        lambda = linsolve(Aw',g);
        if max(isnan(lambda)) == 1            
            error('Equation solve fails,try resolve.');
            % Here we try to resolve
            % disp('Equation solve fails,try resolve.');
            % [rAw,cAw] = size(Aw);
            % lambda = linsolve((Aw+0.001*eye(rAw,cAw))',g);
            % if max(isnan(lambda)) == 1
            %    error('Resolve fails.');
            % end
       end
       if (setSize == 0 || min(lambda) >= 0)
           xStar = x;
           finalAS = w;
           break;
       else
           % Original method to find most violated constraint and remove
           % the corresponding constraint from the working set
           % [~,index] = min(lambda);
           % w(index) = [];
           
           %% Delete the constraint based on Gionata's idea
           [w,consInfo,consInfoNum,hpW,lpW] = deleteCons(lambda,w,consInfo,consInfoNum,hpW,lpW);
           
       end
    else        
        notW = w2notW(w,mc);
        Anotw = zeros(mc-setSize,ndec);
        bnotw = zeros(mc-setSize,1);
        for j = 1:mc-setSize
            Anotw(j,:)  = A(notW(j),:);
            bnotw(j) = b(notW(j));
        end
        
        % Compute the step length alpha
        hasFirst = 0;
        for j = 1:mc-setSize
            ap = Anotw(j,:)*p;
            if (ap < 0)
                if (hasFirst == 0)
                    minAlpha = (bnotw(j)-Anotw(j,:)*x)/ap;
                    indexMin = j;
                    hasFirst = 1;
                else
                    tmpAlpha = (bnotw(j)-Anotw(j,:)*x)/ap;
                    if (tmpAlpha < minAlpha)
                        minAlpha = tmpAlpha;
                        indexMin = j;
                    end
                end
            end
        end
        alpha = min([1,minAlpha]);
        x = x + alpha * p;
        if (alpha < 1)
            tmpW = w;
            w = zeros(setSize+1,1);
            w(1:setSize) = tmpW;
            w(setSize+1) = notW(indexMin);
            w = sort(w);
            indexCons = notW(indexMin);
            
            % Here we check the category of the new added constraint
            [consInfo,consInfoNum] = addToConsInfo(indexCons,consInfo,consInfoNum,nu,ny,M,P);
            % Update hpW and lpW (only non-antecedent)
            [hpW,lpW] = updatePW(consInfo,consInfoNum,nu,ny);
        end
    end
end

zStar = 1/2*xStar'*G*xStar + c'*xStar;

end
