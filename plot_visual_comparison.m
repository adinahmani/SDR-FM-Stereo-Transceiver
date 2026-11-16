function plot_visual_comparison(tx_audio, rx_audio, fs)
    % plot_visual_comparison: Aligns and plots a short snippet from the middle of the signals
    
    % 1. Align the full signals first
    [rx_aligned, tx_aligned] = alignsignals(rx_audio, tx_audio);
    
    % 2. Choose a safe starting point (e.g., 2 seconds in) to avoid 
    % initial zero-padding from alignment and startup transients
    start_sec = 2; 
    start_idx = round(start_sec * fs);
    snippet_len = round(0.05 * fs); % 50 milliseconds
    
    % Ensure we don't go out of bounds if the audio is very short
    if start_idx + snippet_len > min(length(tx_aligned), length(rx_aligned))
        start_idx = 1; 
    end
    
    % 3. Extract the snippets
    tx_snippet = tx_aligned(start_idx : start_idx + snippet_len - 1);
    rx_snippet = rx_aligned(start_idx : start_idx + snippet_len - 1);
    
    % 4. Normalize ONLY the snippets so transient edge spikes don't squash the amplitude
    tx_snippet = tx_snippet / max(abs(tx_snippet));
    rx_snippet = rx_snippet / max(abs(rx_snippet));
    
    % 5. Plot them together
    t_axis = (0:snippet_len-1) / fs;
    figure;
    plot(t_axis, tx_snippet, 'b', 'LineWidth', 1.5); hold on;
    plot(t_axis, rx_snippet, 'r--', 'LineWidth', 1.5);
    title('Visual Comparison: Transmitted vs. Demodulated Audio');
    xlabel('Time (seconds)');
    ylabel('Normalized Amplitude');
    legend('Original Transmitted', 'Demodulated Received');
    grid on;
end

function [correlation, mse] = calc_numerical_comparison(tx_audio, rx_audio, fs)
    % calc_numerical_comparison: Calculates correlation and MSE, avoiding edge transients
    
    % 1. Align signals
    [rx_aligned, tx_aligned] = alignsignals(rx_audio, tx_audio);
    
    % 2. Crop the first and last 1 second to avoid transients and zero-padding
    crop_len = fs; 
    min_len = min(length(tx_aligned), length(rx_aligned));
    
    if min_len > 2*crop_len
        tx_final = tx_aligned(crop_len : min_len-crop_len);
        rx_final = rx_aligned(crop_len : min_len-crop_len);
    else
        tx_final = tx_aligned(1:min_len);
        rx_final = rx_aligned(1:min_len);
    end
    
    % 3. Normalize the cropped sections
    tx_final = tx_final / max(abs(tx_final));
    rx_final = rx_final / max(abs(rx_final));
    
    % 4. Calculate Correlation Coefficient
    R = corrcoef(tx_final, rx_final);
    correlation = R(1,2);
    
    % 5. Calculate Mean Squared Error (MSE)
    mse = sum((tx_final - rx_final).^2) / length(tx_final);
    
    % Print the results to the Command Window
    fprintf('--- Numerical Comparison Results ---\n');
    fprintf('Correlation Coefficient: %.4f (1.0 is perfect)\n', correlation);
    fprintf('Mean Squared Error (MSE): %.6f (0.0 is perfect)\n', mse);
    fprintf('------------------------------------\n');
end