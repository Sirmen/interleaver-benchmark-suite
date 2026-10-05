function is_prime = isInPrimesTable(n, primes_table)
    % Check if n is prime using the loaded primes table
    if n <= 2
        is_prime = true;
        return;
    end
    
    % Binary search in primes table
    is_prime = ismember(n, primes_table);
end
