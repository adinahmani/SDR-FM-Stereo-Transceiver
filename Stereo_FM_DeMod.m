% Stereo_FM_DeMod.m
% FM Receiver for Stereo Audio Stream
clear; clc; close all;

%% 1. Load File
fs_tx   = 1e6;
f_delta = 75e3;
f_p     = 19e3;

% Robust file loading
input_filename = 'tx_stereo.bin';
if ~exist(input_filename, 'file') && exist('rx_data_4MSamples1MsPs_978MHz.bin', 'file')
    input_filename = 'rx_data_4MSamples1MsPs_978MHz.bin';
elseif ~exist(input_filename, 'file') && exist('rx_data_4MSamples1MsPs_97.8MHz.bin', 'file')
    input_filename = 'rx_data_4MSamples1MsPs_97.8MHz.bin';
end

file_info = dir(input_filename);
if isempty(file_info), error('%s not found', input_filename); end

data_len = file_info.bytes / 16;          % 16 bytes per complex double
y_rx     = RD_bin_file(input_filename, data_len); 
y_rx     = y_rx(:);

%% 2. Downsample to Baseband Rate (1 MHz -> 200 kHz)
% Downsample and LPF the received complex signal BEFORE demodulating
fs_bb = 200e3;                           
y_bb  = resample(y_rx, fs_bb, fs_tx);

%% 3. FM Demodulate (phase discriminator at 200 kHz)
phase_y = unwrap(angle(y_bb));
x_comp  = diff(phase_y) * (fs_bb / (2*pi * f_delta));
x_comp  = [x_comp; x_comp(end)];       % restore length

% Drop first 0.1 s transient (calculate index for both sample rates to align plots)
discard_tx = round(0.1*fs_tx)+1;
discard_bb = round(0.1*fs_bb)+1;

y_rx_clean = y_rx(discard_tx : end);     % 1 MHz RF signal
y_bb_clean = y_bb(discard_bb : end);     % 200 kHz RF signal
x_comp     = x_comp(discard_bb : end);   % 200 kHz Demodulated baseband

%% 4. Extract M(t) = (L+R)/2  [0–15 kHz]
[b15, a15] = butter(6, 15e3 / (fs_bb/2), 'low');
M_rx       = filtfilt(b15, a15, x_comp) / 0.9;   % undo 0.9 scale

%% 5. Reconstruct 38 kHz Reference Carrier
t_bb      = (0 : length(x_comp)-1)' / fs_bb;
carrier38 = sin(2 * 2*pi*f_p * t_bb);            % Option A – clean & correct

%% 6. Demodulate DSB-SC to Recover S(t) = (L-R)/2
S_mixed = x_comp .* carrier38;
S_rx    = filtfilt(b15, a15, S_mixed) * (2 / 0.9);

%% 7. Recover Left and Right
L_rec = M_rx + S_rx;    % ← music1  (left)
R_rec = M_rx - S_rx;    % ← piano2  (right)

%% 8. Upsample to Audio Rate and Play
fs_out  = 44100;
L_out   = resample(L_rec, fs_out, fs_bb);
R_out   = resample(R_rec, fs_out, fs_bb);

% Make sure both columns are the same length before concatenating
n_out       = min(length(L_out), length(R_out));
audio_final = [L_out(1:n_out), R_out(1:n_out)];          % Nx2 stereo matrix

% Normalise
audio_final = audio_final / (max(abs(audio_final(:))) + 1e-10);
fprintf('Playing stereo audio from %s...\n', input_filename);
soundsc(audio_final, fs_out);

%% 9. Diagnostic Plots: Demodulation Phase Tracking

% --- Setup Time Vectors ---
t_tx  = (0:length(y_rx_clean)-1)' / fs_tx;
t_bb  = (0:length(y_bb_clean)-1)' / fs_bb;
t_out = (0:n_out-1)' / fs_out;

% --- Setup FFT Computations (Cap at 1M points for processing speed) ---
% 1. Received RF (1 MHz)
N_tx = min(length(y_rx_clean), 1e6);
X_rx_fft = fftshift(fft(y_rx_clean(1:N_tx)));
f_tx = (-N_tx/2 : N_tx/2-1) * (fs_tx / N_tx);

% 2. Downsampled RF & Filtered Phases (200 kHz)
N_bb = min(length(y_bb_clean), 1e6);
X_bb_fft   = fftshift(fft(y_bb_clean(1:N_bb)));
X_comp_fft = fftshift(fft(x_comp(1:N_bb)));
M_rx_fft   = fftshift(fft(M_rx(1:N_bb)));
S_rx_fft   = fftshift(fft(S_rx(1:N_bb)));
f_bb = (-N_bb/2 : N_bb/2-1) * (fs_bb / N_bb);

% 3. Final Audio (44.1 kHz)
N_out = min(n_out, 5e5);
L_out_fft = fftshift(fft(audio_final(1:N_out, 1)));
R_out_fft = fftshift(fft(audio_final(1:N_out, 2)));
f_out = (-N_out/2 : N_out/2-1) * (fs_out / N_out);

% Helper logic to calculate clean integer Y-limits
get_y_lims = @(sig) max(1, ceil(max(abs(sig(:))))); 

% =========================================================================
% FIGURE 1: Phase 1 - Received Signal (1 MHz RF)
% =========================================================================
figure('Name', 'Phase 1: Received RF Signal', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(t_tx, real(y_rx_clean), 'g', 'LineWidth', 0.5);
title('1. Received Signal (y_{rx}) - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_tx(end)]); grid on;
xticks(0:ceil(t_tx(end))); % Force time axis to integers 0, 1, 2, 3...
y_max = get_y_lims(real(y_rx_clean)); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

subplot(2, 1, 2);
plot(f_tx / 1e5, 20*log10(abs(X_rx_fft) + 1e-10), 'g');
title('1. Received Signal - Frequency Domain');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-5 5]); grid on; % 1 MHz bandwidth maps to -5 to 5

% =========================================================================
% FIGURE 2: Phase 2 - Downsampled Received Signal (200 kHz RF)
% =========================================================================
figure('Name', 'Phase 2: Downsampled Received Signal', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(t_bb, real(y_bb_clean), 'Color', [0.3 0.7 0.3], 'LineWidth', 0.5);
title('2. Downsampled Received Signal (200 kHz) - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_bb(end)]); grid on;
xticks(0:ceil(t_bb(end)));
y_max = get_y_lims(real(y_bb_clean)); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

subplot(2, 1, 2);
plot(f_bb / 1e5, 20*log10(abs(X_bb_fft) + 1e-10), 'Color', [0.3 0.7 0.3]);
title('2. Downsampled Received Signal - Frequency Domain');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-1 1]); grid on; 

% =========================================================================
% FIGURE 3: Phase 3 - FM Demodulated Signal (MPX Baseband)
% =========================================================================
figure('Name', 'Phase 3: FM Demodulated Signal', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(t_bb, x_comp, 'b', 'LineWidth', 0.5);
title('3. FM Demodulated MPX Signal (x_{comp}) - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_bb(end)]); grid on;
xticks(0:ceil(t_bb(end)));
y_max = get_y_lims(x_comp); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

subplot(2, 1, 2);
plot(f_bb / 1e5, 20*log10(abs(X_comp_fft) + 1e-10), 'b');
title('3. FM Demodulated MPX Signal - Frequency Domain');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-1 1]); grid on; % 200 kHz bandwidth limits force 0.2, 0.4 etc ticks
xline(0.19, '--r', '19k Pilot'); xline(0.38, '--g', '38k Subcarrier');
xline(-0.19, '--r'); xline(-0.38, '--g');

% =========================================================================
% FIGURE 4: Phase 4 - L+R (Mono) Component
% =========================================================================
figure('Name', 'Phase 4: L+R (Mono) Component', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(t_bb, M_rx, 'b', 'LineWidth', 0.5);
title('4. Mono M(t) = (L+R)/2 - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_bb(end)]); grid on;
xticks(0:ceil(t_bb(end)));
y_max = get_y_lims(M_rx); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

subplot(2, 1, 2);
plot(f_bb / 1e5, 20*log10(abs(M_rx_fft) + 1e-10), 'b');
title('4. Mono M(t) - Frequency Domain');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-0.3 0.3]); grid on; % Zoomed in to clearly show 0.1, 0.2 ticks
xline(0.15, '--k', '15k Limit'); xline(-0.15, '--k');

% =========================================================================
% FIGURE 5: Phase 5 - L-R (Stereo Difference) Component
% =========================================================================
figure('Name', 'Phase 5: L-R (Stereo Diff) Component', 'NumberTitle', 'off');
subplot(2, 1, 1);
plot(t_bb, S_rx, 'r', 'LineWidth', 0.5);
title('5. Stereo S(t) = (L-R)/2 - Time Domain');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_bb(end)]); grid on;
xticks(0:ceil(t_bb(end)));
y_max = get_y_lims(S_rx); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

subplot(2, 1, 2);
plot(f_bb / 1e5, 20*log10(abs(S_rx_fft) + 1e-10), 'r');
title('5. Stereo S(t) - Frequency Domain');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-0.3 0.3]); grid on;
xline(0.15, '--k', '15k Limit'); xline(-0.15, '--k');

% =========================================================================
% FIGURE 6: Phase 6 - Final Reconstructed Audio (Left & Right)
% =========================================================================
figure('Name', 'Phase 6: Final Audio Channels', 'NumberTitle', 'off');

% Left Time
subplot(2, 2, 1);
plot(t_out, audio_final(:,1), 'b', 'LineWidth', 0.5);
title('Left Channel (Music) - Time');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_out(end)]); grid on;
xticks(0:ceil(t_out(end)));
y_max = get_y_lims(audio_final(:,1)); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

% Left Freq
subplot(2, 2, 2);
plot(f_out / 1e5, 20*log10(abs(L_out_fft) + 1e-10), 'b');
title('Left Channel - Freq');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-0.22 0.22]); grid on;

% Right Time
subplot(2, 2, 3);
plot(t_out, audio_final(:,2), 'r', 'LineWidth', 0.5);
title('Right Channel (Piano) - Time');
xlabel('Time (s)'); ylabel('Amplitude'); xlim([0 t_out(end)]); grid on;
xticks(0:ceil(t_out(end)));
y_max = get_y_lims(audio_final(:,2)); ylim([-y_max y_max]); yticks(-y_max:1:y_max);

% Right Freq
subplot(2, 2, 4);
plot(f_out / 1e5, 20*log10(abs(R_out_fft) + 1e-10), 'r');
title('Right Channel - Freq');
xlabel('Frequency [\times 10^5 Hz]'); ylabel('Magnitude (dB)');
xlim([-0.22 0.22]); grid on;