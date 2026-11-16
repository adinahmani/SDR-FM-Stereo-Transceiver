% Stereo_FM_Mod.m
% FM Transmitter for Stereo Audio Stream
clear; clc; close all;

%% 1. Read and Prepare Audio Files
[left_audio,  fs_orig] = audioread('music1.wav');
[right_audio, ~]       = audioread('piano2.wav');
if size(left_audio,  2) > 1, left_audio  = mean(left_audio,  2); end
if size(right_audio, 2) > 1, right_audio = mean(right_audio, 2); end
min_len     = min(length(left_audio), length(right_audio));
max_samples = min(min_len, 10 * fs_orig);
left_audio  = left_audio(1:max_samples);
right_audio = right_audio(1:max_samples);

%% 2. Resample to Intermediate Baseband Rate (200 kHz) and Filter
fs_bb = 200e3; % 200 kHz Baseband Processing Rate
L_resampled = resample(left_audio,  fs_bb, fs_orig);
R_resampled = resample(right_audio, fs_bb, fs_orig);

[b15, a15] = butter(6, 15e3 / (fs_bb/2), 'low');
L_filtered  = filtfilt(b15, a15, L_resampled);
R_filtered  = filtfilt(b15, a15, R_resampled);

% Normalize both channels together to preserve relative volume
max_val = max(max(abs(L_filtered)), max(abs(R_filtered)));
L = L_filtered / max_val;
R = R_filtered / max_val;

%% 3. Build Stereo Composite (MPX) Signal at 200 kHz
%  Standard FM-Stereo baseband composite:
%    x_comp(t) = 0.9 * [ M(t) + S(t)*sin(2*2*pi*f_p*t) ] + 0.1 * sin(2*pi*f_p*t)
%  where:
%    M(t) = (L+R)/2   – mono sum   (0-15 kHz)
%    S(t) = (L-R)/2   – difference (DSB-SC at 38 kHz)
%    pilot at 19 kHz (amplitude 0.1) tells the receiver the signal is stereo
M_t = (L + R) / 2;
S_t = (L - R) / 2;
t   = (0 : length(M_t)-1)' / fs_bb;
f_p = 19e3;

pilot_tone    = 0.1 * sin(2*pi*f_p*t);          % 19 kHz pilot
subcarrier_38 = sin(2 * 2*pi*f_p * t);          % 38 kHz carrier  ← sin(4*pi*f_p*t)
DSB_SC        = S_t .* subcarrier_38;           % DSB-SC difference signal
x_comp = 0.9 * (M_t + DSB_SC) + pilot_tone;     % composite baseband

%% 4. FM Modulate at 200 kHz
f_delta    = 75e3;
integral_x = cumsum(x_comp) / fs_bb;
y_bb       = exp(1j * 2*pi * f_delta * integral_x);

%% 5. Phase 5: Interpolator Block Diagram (Upsample to 1 MHz)
fs_tx = 1e6; % Final USRP transmission rate
L_interp = fs_tx / fs_bb; % Interpolation factor L = 5

% Step A: Zero-Insertion (Expander)
y_up = upsample(y_bb, L_interp);

% Step B: Anti-Imaging Low-Pass Filter
% Cutoff just below the 200kHz Nyquist limit (100 kHz) to remove imaging replicas
[b_int, a_int] = butter(6, 90e3 / (fs_tx/2), 'low');

% Filter the signal and multiply by L to recover energy lost during zero-insertion
y_tx = filtfilt(b_int, a_int, y_up) * L_interp;

%% 6. Save
WR_bin_file('tx_stereo.bin', y_tx);
fprintf('Saved → tx_stereo.bin\n');

%% 7. Diagnostic Plots: Domain Tracking 

% --- Setup Time Vectors ---
t_orig = (0:length(left_audio)-1)' / fs_orig;
t_bb   = (0:length(L)-1)' / fs_bb;
t_tx   = (0:length(y_tx)-1)' / fs_tx;

% --- Setup FFT Computations (Cap at 1M points for processing speed) ---
% Original Phase FFTs
N_orig = length(left_audio);
L_orig_fft = fftshift(fft(left_audio));
R_orig_fft = fftshift(fft(right_audio));
f_orig = (-N_orig/2 : N_orig/2-1) * (fs_orig / N_orig);

% 200 kHz Baseband Phase FFTs
N_bb = min(length(L), 1e6); 
L_res_fft  = fftshift(fft(L(1:N_bb)));
R_res_fft  = fftshift(fft(R(1:N_bb)));
x_comp_fft = fftshift(fft(x_comp(1:N_bb)));
y_bb_fft   = fftshift(fft(y_bb(1:N_bb)));
f_bb = (-N_bb/2 : N_bb/2-1) * (fs_bb / N_bb);

% 1 MHz Interpolated Phase FFTs
N_tx = min(length(y_tx), 1e6);
y_tx_fft = fftshift(fft(y_tx(1:N_tx)));
f_tx = (-N_tx/2 : N_tx/2-1) * (fs_tx / N_tx);

% =========================================================================
% FIGURE 1: Phase 1 - Original Audio (Raw WAV Files)
% =========================================================================
figure('Name', 'Phase 1: Original Audio Streams', 'NumberTitle', 'off');

% Left Channel (Music) - Time
subplot(2, 2, 1);
plot(t_orig, left_audio, 'b', 'LineWidth', 0.5);
title('Original Left Channel (Music1) - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_orig(end)]); grid on;

% Left Channel (Music) - Frequency
subplot(2, 2, 2);
plot(f_orig/1e3, 20*log10(abs(L_orig_fft) + 1e-10), 'b');
title('Original Left Channel (Music1) - Freq Domain');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
xlim([-fs_orig/(2e3) fs_orig/(2e3)]); grid on;

% Right Channel (Piano) - Time
subplot(2, 2, 3);
plot(t_orig, right_audio, 'r', 'LineWidth', 0.5);
title('Original Right Channel (Piano2) - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_orig(end)]); grid on;

% Right Channel (Piano) - Frequency
subplot(2, 2, 4);
plot(f_orig/1e3, 20*log10(abs(R_orig_fft) + 1e-10), 'r');
title('Original Right Channel (Piano2) - Freq Domain');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
xlim([-fs_orig/(2e3) fs_orig/(2e3)]); grid on;

% =========================================================================
% FIGURE 2: Phase 2 - Resampled and Filtered Audio (200 kHz Rate)
% =========================================================================
figure('Name', 'Phase 2: Resampled and Filtered (15 kHz cutoff)', 'NumberTitle', 'off');

% Left Channel Filtered - Time
subplot(2, 2, 1);
plot(t_bb, L, 'b', 'LineWidth', 0.5);
title('Filtered Left Channel - Time Domain');
xlabel('Time (s)'); ylabel('Normalized Amplitude'); xlim([0 t_bb(end)]); grid on;

% Left Channel Filtered - Frequency
subplot(2, 2, 2);
plot(f_bb/1e3, 20*log10(abs(L_res_fft) + 1e-10), 'b');
title('Filtered Left Channel - Freq Domain');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
xlim([-30 30]); grid on; % Zoomed in to show cutoff
xline(15, '--k', '15 kHz Cutoff', 'LabelVerticalAlignment', 'bottom'); xline(-15, '--k');

% Right Channel Filtered - Time
subplot(2, 2, 3);
plot(t_bb, R, 'r', 'LineWidth', 0.5);
title('Filtered Right Channel - Time Domain');
xlabel('Time (s)'); ylabel('Normalized Amplitude'); xlim([0 t_bb(end)]); grid on;

% Right Channel Filtered - Frequency
subplot(2, 2, 4);
plot(f_bb/1e3, 20*log10(abs(R_res_fft) + 1e-10), 'r');
title('Filtered Right Channel - Freq Domain');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
xlim([-30 30]); grid on; % Zoomed in to show cutoff
xline(15, '--k', '15 kHz Cutoff', 'LabelVerticalAlignment', 'bottom'); xline(-15, '--k');

% =========================================================================
% FIGURE 3: Phase 3 - Stereo Signal (Matches Lab Report Image)
% =========================================================================
figure('Name', 'Phase 3: Stereo Signal', 'NumberTitle', 'off');

% Stereo Signal - Time Domain (Matches Blue Plot)
subplot(2, 1, 1);
plot(t_bb, x_comp, 'b', 'LineWidth', 0.5);
title('Time Domain');
xlabel('Time [sec]'); ylabel('Amplitude'); 
xlim([0 t_bb(end)]); 

% Stereo Signal - Frequency Domain (Matches Green Plot)
subplot(2, 1, 2);
plot(f_bb, 20*log10(abs(x_comp_fft) + 1e-10), 'g', 'LineWidth', 0.5);
title('Frequency Domain');
xlabel('Frequency [Hz]'); ylabel('Amplitude');
xlim([-1e5 1e5]); % Sets the x-axis to perfectly match the 10^5 scale in the image
ylim([-50 max(20*log10(abs(x_comp_fft))) + 10]); % Matches the -50 dB floor from the image

% =========================================================================
% FIGURE 4: Phase 4 - FM Modulated Signal (200 kHz Baseband)
% =========================================================================
figure('Name', 'Phase 4: FM Modulated Signal (200 kHz Baseband)', 'NumberTitle', 'off');

% FM Modulated - Time Domain
subplot(2, 1, 1);
plot(t_bb, real(y_bb), 'b', 'LineWidth', 0.5);
title('FM Modulated Signal (200 kHz) - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude'); 
xlim([0 t_bb(end)]); % Displaying full time axis in seconds
grid on;

% FM Modulated - Frequency Domain
subplot(2, 1, 2);
plot(f_bb / 1e5, 20*log10(abs(y_bb_fft) + 1e-10), 'b');
title('FM Modulated Signal (200 kHz) - Frequency Domain');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-1 1]); % Force decimal formatting (0.1, 0.2, etc.) exactly up to the 100kHz Nyquist edge
grid on;

% =========================================================================
% FIGURE 5: Phase 5 - Final Interpolated Modulated Signal (1 MHz)
% =========================================================================
figure('Name', 'Phase 5: Final Modulated Signal (1 MHz Upsampled)', 'NumberTitle', 'off');

% Final Modulated Signal - Time Domain
subplot(2, 1, 1);
plot(t_tx, real(y_tx), 'b', 'LineWidth', 0.5);
title('Final FM Modulated Signal (1 MHz) - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude');
xlim([0 t_tx(end)]); 
grid on;

% Final Modulated Signal - Frequency Domain
subplot(2, 1, 2);
plot(f_tx / 1e5, 20*log10(abs(y_tx_fft) + 1e-10), 'b');
title('Final FM Modulated Signal (1 MHz) - Frequency Domain');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-fs_tx/(2e5) fs_tx/(2e5)]); % Display the full 1 MHz bandwidth limits (-5 to 5)
grid on;