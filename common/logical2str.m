function str = logical2str(val)
    % Convert logical to Yes/No string
    if val
        str = 'Yes';
    else
        str = 'No';
    end
end
