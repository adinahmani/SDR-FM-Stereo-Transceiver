% Mono_Fm_Mod.m
% FM Transmitter for Mono Audio Stream with Diagnostic Visualizations
clear; clc; close all;

%% 1. Read the audio file
filename = 'piano2.wav';
[x, fs_orig] = audioread(filename);

% Ensure the signal is mono (if stereo, take the average of the channels)
if size(x, 2) > 1
    x = mean(x, 2);
end

% Take a 15-second segment if the file is longer
max_len = 15 * fs_orig;
if length(x) > max_len
    x = x(1:max_len);
end

%% 2. Up-sample to 200 kHz and filter
fs1 = 200e3; % First stage sampling rate (200 kHz)
x_resampled = resample(x, fs1, fs_orig); % Up-sample

% Filter the signal to a one-sided bandwidth of 15 kHz
% Using a Butterworth lowpass filter
f_cutoff = 15e3;
[b, a] = butter(6, f_cutoff / (fs1 / 2), 'low');
x_filtered = filtfilt(b, a, x_resampled);

% Normalize x(t) so that |x(t)| <= 1
x_norm = x_filtered / max(abs(x_filtered));

%% 3. Modulate the signal (FM) manually at 200 kHz
f_delta = 75e3; % Frequency deviation of 75 kHz
dt = 1 / fs1;   % Time step

% The FM modulation baseband representation is y(t) = exp(j * 2 * pi * f_delta * integral(x(t)))
% We approximate the integral using cumulative sum
integral_x = cumsum(x_norm) * dt;

% Baseband complex modulated signal
y_modulated = exp(1i * 2 * pi * f_delta * integral_x);

%% 4. Up-sample to 1 MHz for USRP (Interpolator Block Diagram)
fs2 = 1e6; % Final USRP sampling rate (1 MHz)
L_interp = fs2 / fs1; % Interpolation factor L = 5

% Step A: Zero-Insertion (Expander)
y_up = upsample(y_modulated, L_interp);

% Step B: Anti-Imaging Low-Pass Filter
% Cutoff just below the 100kHz Nyquist limit to remove imaging replicas
[b_int, a_int] = butter(6, 90e3 / (fs2/2), 'low');

% Filter the signal and multiply by L to recover energy lost during zero-insertion
y_upsampled = filtfilt(b_int, a_int, y_up) * L_interp;

%% 5. Save the data to a .bin file
output_filename = 'tx_mono.bin';
try
    WR_bin_file(output_filename, y_upsampled);
    disp(['Successfully saved modulated signal to ', output_filename]);
catch
    warning('WR_bin_file.m not found in path. Please ensure the lab files are included.');
end

%% 6. Generate Diagnostic Plots

% Helper logic to calculate clean integer Y-limits
get_y_lims = @(sig) max(1, ceil(max(abs(sig(:))))); 

% --- Setup Time Vectors ---
t_orig  = (0 : length(x)-1)' / fs_orig;
t_res   = (0 : length(x_norm)-1)' / fs1;
t_final = (0 : length(y_upsampled)-1)' / fs2;

% --- Setup FFT Computations ---
N_orig = length(x);
X_orig_fft = fftshift(fft(x));
f_orig_axis = (-N_orig/2 : N_orig/2-1) * (fs_orig / N_orig);

N_res = length(x_norm);
X_res_fft = fftshift(fft(x_norm));
f_res_axis = (-N_res/2 : N_res/2-1) * (fs1 / N_res);

N_mod = length(y_modulated);
Y_mod_fft = fftshift(fft(y_modulated));
f_mod_axis = (-N_mod/2 : N_mod/2-1) * (fs1 / N_mod);

N_final = min(length(y_upsampled), 1e6); % Cap at 1M points for speed
Y_final_fft = fftshift(fft(y_upsampled(1:N_final)));
f_final_axis = (-N_final/2 : N_final/2-1) * (fs2 / N_final);

% =========================================================================
% FIGURE 1: Original vs. Filtered vs. 200kHz Modulated
% =========================================================================
figure('Name', 'FM Modulator Analysis: Original vs. Filtered vs. Modulated', 'NumberTitle', 'off');

% Subplot 1: Original Signal in Time Domain
subplot(3, 2, 1);
plot(t_orig, x, 'b', 'LineWidth', 0.5);
title('Original Signal (Time Domain)');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_orig(end)]); grid on;
y_max = get_y_lims(x); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

% Subplot 2: Original Signal in Frequency Domain
subplot(3, 2, 2);
plot(f_orig_axis / 1e3, 20*log10(abs(X_orig_fft) + 1e-10), 'b');
title('Original Signal (Frequency Domain)');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
xlim([-fs_orig/(2*1e3) fs_orig/(2*1e3)]); grid on;

% Subplot 3: Resampled & Filtered Signal in Time Domain
subplot(3, 2, 3);
plot(t_res, x_norm, 'r', 'LineWidth', 0.5);
title('Resampled & Filtered Signal (Time Domain)');
xlabel('Time (s)'); ylabel('Normalized Amplitude'); xlim([0 t_res(end)]); grid on;
y_max = get_y_lims(x_norm); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

% Subplot 4: Resampled & Filtered Signal in Frequency Domain
subplot(3, 2, 4);
plot(f_res_axis / 1e3, 20*log10(abs(X_res_fft) + 1e-10), 'r');
title('Resampled & Filtered Signal (Frequency Domain)');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
xlim([-30 30]); grid on;
xline(15, '--k', '15 kHz Cutoff', 'LabelHorizontalAlignment', 'right'); xline(-15, '--k');

% Subplot 5: Modulated FM Signal (200 kHz) in Time Domain
subplot(3, 2, 5);
plot(t_res, real(y_modulated), 'g', 'LineWidth', 0.5);
title('Modulated FM Signal @ 200 kHz (Time Domain - Real Part)');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_res(end)]); grid on;
y_max = get_y_lims(real(y_modulated)); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

% Subplot 6: Modulated FM Signal (200 kHz) in Frequency Domain (10^5 format)
subplot(3, 2, 6);
plot(f_mod_axis / 1e5, 20*log10(abs(Y_mod_fft) + 1e-10), 'g');
title('Modulated FM Signal @ 200 kHz (Frequency Domain)');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-1 1]); grid on; % Show complete 200 kHz Nyquist bandwidth mapped to -1 to 1

% =========================================================================
% FIGURE 2: Final Upsampled FM Signal (1 MHz)
% =========================================================================
figure('Name', 'Final 1 MHz Modulated Signal', 'NumberTitle', 'off');

% Subplot 1: Final Modulated Signal in Time Domain
subplot(2, 1, 1);
plot(t_final, real(y_upsampled), 'b', 'LineWidth', 0.5);
title('Final Modulated FM Signal @ 1 MHz (Time Domain)');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_final(end)]); grid on;
y_max = get_y_lims(real(y_upsampled)); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

% Subplot 2: Final Modulated Signal in Frequency Domain (10^5 format)
subplot(2, 1, 2);
plot(f_final_axis / 1e5, 20*log10(abs(Y_final_fft) + 1e-10), 'b');
title('Final Modulated FM Signal @ 1 MHz (Frequency Domain)');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-5 5]); grid on; % Show complete 1 MHz Nyquist bandwidth mapped to -5 to 5