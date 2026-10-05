function latinSquare = createLatinSquare(n, interleave)
    % create a latinsquare with order: n
    % by Niki ---2012/9/18
    % the interleave style has a better order balance especially if n is
    % large, to get a latinsquare with interleve style: CreatLatinSquare(n,1).
    % by Niki---2013/3/18
    % rewrite alghrithm to imporve speed
    % by Niki 2014/7/1
    % test:
    if nargin == 0
        createLatinSquare(10,1);
        createLatinSquare(9,0);
        createLatinSquare(10,0);
        createLatinSquare(9,1);
        return;
    end
    if nargin < 2
        interleave = 1;
    end
    latinSquare = nan(n);
    latinSquare(:,1) = 1:n;
    if interleave == 1
        shiftsize = (.5 - mod(1:n-1, 2))/.5 .* ceil((1:n-1)/2);
    else
        shiftsize = n-1:-1:1;
    end
    for col = 2:n
        latinSquare(:,col) = circshift((1:n)', shiftsize(col-1));
    end
end
