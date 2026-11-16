function [correlation, mse] = calc_numerical_comparison(tx_audio, rx_audio)
% calc_numerical_comparison: Calculates correlation and MSE between signals

% 1. Normalize to ensure a fair mathematical comparison
tx_norm = tx_audio / max(abs(tx_audio));
rx_norm = rx_audio / max(abs(rx_audio));

% 2. Align the signals (crucial for accurate MSE)
[rx_aligned, tx_aligned] = alignsignals(rx_norm, tx_norm);

% Make sure they are exactly the same length after alignment
min_len = min(length(tx_aligned), length(rx_aligned));
tx_final = tx_aligned(1:min_len);
rx_final = rx_aligned(1:min_len);

% 3. Calculate Correlation Coefficient
R = corrcoef(tx_final, rx_final);
correlation = R(1,2);

% 4. Calculate Mean Squared Error (MSE)
mse = sum((tx_final - rx_final).^2) / min_len;

% Print the results to the Command Window
fprintf('--- Numerical Comparison Results ---\n');
fprintf('Correlation Coefficient: %.4f (1.0 is perfect)\n', correlation);
fprintf('Mean Squared Error (MSE): %.6f (0.0 is perfect)\n', mse);
fprintf('------------------------------------\n');
end