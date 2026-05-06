# Fringe Resolved SHG Interferometric Autocorrelation Simulator

A MATLAB forward simulator for fringe resolved second harmonic generation, SHG, interferometric autocorrelation of ultrafast laser pulses.

This code helps visualize how an ultrafast pulse and its autocorrelation trace change when the pulse accumulates dispersion from optical components between the laser source and the autocorrelator.

It can be used as a debugging tool, a forward model, or a learning tool for understanding why a measured fringe resolved autocorrelation trace may look different from an ideal transform limited pulse.

---

## What this code does

The simulator calculates a fringe resolved SHG autocorrelation trace using

\[
S(\tau) \propto \int |E(t) + E(t-\tau)|^4 dt
\]

where \(E(t)\) is the electric field of the pulse and \(\tau\) is the delay between two replicas of the pulse.

The code can start from either:

- A measured laser spectrum
- A Gaussian temporal pulse
- A sech temporal pulse
- A super Gaussian temporal pulse
- A user defined custom temporal pulse

Then it applies spectral phase from optical components such as:

- Chirped mirrors
- Dielectric mirrors
- Bragg mirrors
- Air propagation
- Glass or other optical media
- Compressor optics
- Nonlinear crystal/substrate inside the autocorrelator
- Any additional user defined optical component

The code then simulates:

- Fringe resolved SHG autocorrelation trace
- Background free intensity autocorrelation
- Optional movie showing the autocorrelation trace buildup
- Optional diagnostic plots for spectrum, spectral phase, temporal intensity, and FFT of the autocorrelation trace

---

## Why this is useful

When working with short pulses, especially near 10 fs or below, even small amounts of dispersion can strongly affect the measured autocorrelation trace.

There may be many optical components between the laser head and the autocorrelator. Each one can contribute group delay, GDD, TOD, or higher order phase.

This simulator lets the user include those known or estimated contributions and see how the autocorrelation trace changes.

It is especially useful for students and researchers learning:

- Fringe resolved autocorrelation
- SHG autocorrelation
- GDD and TOD
- Spectral phase
- Few cycle pulse distortion
- Effects of mirrors, air, glass, and autocorrelator crystals

---

## What this code is not

This code is not a replacement for full pulse retrieval methods such as:

- FROG
- SPIDER
- d-scan
- MIIPS

It is a forward simulator. It shows what autocorrelation trace is expected from a given input pulse and a given set of dispersion terms.

It does not uniquely retrieve the full electric field from an experimental trace.

---

## Input options

The main input type is selected near the beginning of the MATLAB file:

```matlab
input_type = 'spectrum';
