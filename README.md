# Software-Defined Radio (SDR) Stereo FM Transceiver

An end-to-end Software-Defined Radio (SDR) digital communications project designed, implemented, and validated using **MATLAB** and **National Instruments (NI) USRP** hardware.

The system implements a full physical-layer transceiver capable of transmitting and receiving commercial-grade stereo FM audio over the air. It features multi-rate digital signal processing (DSP), composite baseband multiplexing (MPX), anti-aliasing/anti-imaging filtering, and quantitative hardware-in-the-loop validation.

---

## System Architecture

The physical transceiver pipeline follows the commercial FM stereo broadcasting standard:

```
TRANSMITTER (TX) CHAIN:
[Audio Files (L & R)] (44.1 kHz)
         │
         ▼
[Polyphase Resampling & 15 kHz 6th-Order Butterworth LPF] (200 kHz)
         │
         ▼
[Stereo MPX Encoder: Mono (L+R), DSB-SC Stereo (L-R) @ 38 kHz, 19 kHz Pilot Tone]
         │
         ▼
[FM Phase Integration & Modulator (Peak Deviation Δf = 75 kHz)]
         │
         ▼
[Anti-Imaging Interpolation Filter to DAC Rate] (1 MHz)
         │
         ▼
[NI USRP 2920 RF Front-End] ─── Over-the-Air Wireless Transmission (~98 MHz) ───┐
                                                                                 │
RECEIVER (RX) CHAIN:                                                            │
[NI USRP 2920 Receiver Front-End] ◄─────────────────────────────────────────────┘
  (Over-the-Air RF Capture @ 1 MS/s IQ Baseband)
         │
         ▼
[Decimation & Channel Selection Filter] (1 MHz → 200 kHz)
         │
         ▼
[FM Quadrature Phase Differentiator]
         │
         ▼
[Stereo Matrix Demultiplexer & De-emphasis] (L = M + S, R = M - S)
         │
         ▼
[Audio Reconstruction & Soundcard Resampling] (44.1 kHz Stereo Output)
```

---

## Key Engineering Highlights

* **Multi-Rate DSP & Filter Design:** Designed cascaded anti-aliasing and interpolation filters (6th-order low-pass Butterworth) across multiple sampling domains ($44.1\text{ kHz} \rightarrow 200\text{ kHz} \rightarrow 1\text{ MHz}$) to prevent aliasing and eliminate out-of-band imaging spurs.
* **Stereo Multiplexing (MPX):** Formatted the composite baseband signal with Mono sum $M(t) = \frac{L(t) + R(t)}{2}$, DSB-SC modulated stereo difference $S(t) = \frac{L(t) - R(t)}{2}$ on a $38\text{ kHz}$ subcarrier, and a synchronized $19\text{ kHz}$ pilot tone.
* **Hardware Integration (NI USRP-2920):** Configured RF carrier frequency, TX/RX gain stages, and streaming over Gigabit Ethernet. Transmitted and captured raw physical baseband IQ data.
* **Quantitative Validation & Signal Fidelity:** Implemented automated analysis to quantify fidelity between transmitted and received signals:
  * **Mean Squared Error (MSE):** Verified $MSE < 10^{-6}$ after cross-correlation delay alignment.
  * **Cross-Correlation ($R$):** Near-unity correlation ($R \approx 1.0$) confirming zero non-linear harmonic distortion.
  * **Spectral Mask Compliance:** Verified via Spectrum Analyzer to adhere strictly to the $75\text{ kHz}$ maximum deviation limit without adjacent-channel interference.

---

## Validation & Hardware Results

### 1. Real-Time Hardware Capture (NI USRP & LabVIEW)
The raw over-the-air baseband RF stream is captured at $1\text{ MS/s}$ (Nyquist bandwidth of $1\text{ MHz}$) with a $30\text{ dB}$ receiver front-end gain:

![Hardware Capture](assets/hardware_capture_labview.png)

---

### 2. Baseband Interpolation & Transmit Spectrum
To feed data seamlessly to the USRP DAC hardware layer, the signal undergoes high-rate interpolation to $1\text{ MHz}$. The anti-imaging filter ensures sharp out-of-band suppression:

![Interpolation & Spectrum](assets/baseband_interpolation_spectrum.png)

---

### 3. Receiver Processing & Decimation Stages
The received $1\text{ MHz}$ signal is decimated by a factor of 5 down to $200\text{ kHz}$, followed by the phase discriminator loop to reconstruct the baseband audio envelope:

![Receiver Stages](assets/signal_stages_decimation.png)

---

### 4. Transmitted vs. Demodulated Audio Waveform Tracking
Zoomed-in time-domain comparison between the transmitted audio (solid blue line) and recovered demodulated signal (dashed red line):

![Waveform Tracking](assets/audio_waveform_comparison.png)

The recovered waveform matches the original tone with exceptional precision across all dynamic transitions and micro-peaks.

---

## Repository Structure

```
├── README.md                      # Project documentation and performance analysis
├── .gitignore                     # Git ignore rules for MATLAB artifacts and binary dumps
├── Stereo_FM_Mod.m                # Transmit chain (Conditioning, MPX multiplexing, FM modulation, USRP interpolation)
├── Stereo_FM_DeMod.m              # Receive chain (Decimation, phase discriminator demodulation, dematrixing)
├── Mono_Fm_Mod.m                  # Single-channel FM transmitter reference implementation
├── Mono_Fm_DeMod.m                # Single-channel FM receiver reference implementation
├── calc_numerical_comparison.m    # Signal delay alignment, cross-correlation, and MSE metric calculation
├── plot_visual_comparison.m       # Time- and frequency-domain visual inspection tool
├── RD_bin_file.m                  # Fast binary file reader for raw USRP complex IQ samples
├── WR_bin_file.m                  # Binary file writer for streaming IQ samples to hardware
├── music1.wav                     # Test audio sample (Left channel)
├── piano2.wav                     # Test audio sample (Right channel)
└── assets/                        # Hardware captures, spectral plots, and visual results
    ├── hardware_capture_labview.png
    ├── baseband_interpolation_spectrum.png
    ├── signal_stages_decimation.png
    └── audio_waveform_comparison.png
```

---

## Requirements & Tools

* **Software:** MATLAB (Signal Processing Toolbox)
* **Hardware Drivers:** LabVIEW / NI-USRP driver suite
* **Hardware:** NI USRP-2920 Software-Defined Radio, Spectrum Analyzer
