# Fringe Resolved SHG Interferometric Autocorrelation Simulator

A MATLAB forward simulator for fringe resolved second harmonic generation, SHG, interferometric autocorrelation of ultrafast laser pulses.

This code helps visualize how an ultrafast pulse and its autocorrelation trace change when the pulse accumulates dispersion from optical components between the laser source and the autocorrelator.

It can be used as a debugging tool, forward model, or a learning tool for understanding why a measured fringe resolved autocorrelation trace may look different from an ideal transform limited pulse.

---

## Purpose

Short ultrafast pulses are very sensitive to dispersion.

Even if the pulse is close to transform limited at the laser output, the measured autocorrelation trace can change after the pulse passes through:

- chirped mirrors
- dielectric mirrors
- Bragg mirrors
- air
- glass
- compressor optics
- nonlinear crystal or substrate inside the autocorrelator
- any other optical element in the beam path

This simulator lets the user include these phase contributions and see how the fringe resolved SHG autocorrelation trace changes.

---

## What this code does

The code starts from either:

- a measured laser spectrum
- a Gaussian temporal pulse
- a sech temporal pulse
- a super Gaussian temporal pulse
- a user defined custom temporal pulse

Then it applies spectral phase from optical components.

The final pulse is used to calculate the fringe resolved SHG interferometric autocorrelation trace.

The main autocorrelation model is

$$
S(\tau) \propto \int_{-\infty}^{\infty}
\left|E(t) + E(t-\tau)\right|^4 dt
$$

where \(E(t)\) is the electric field of the pulse and \(\tau\) is the delay between the two replicas of the pulse.

This expression comes from the SHG field being proportional to the square of the total electric field:

$$
E_{2\omega}(t,\tau) \propto \left[E(t) + E(t-\tau)\right]^2
$$

and the measured SHG signal being proportional to the time integrated intensity:

$$
S(\tau) \propto \int \left|E_{2\omega}(t,\tau)\right|^2 dt
$$

Therefore,

$$
S(\tau) \propto \int
\left|\left[E(t) + E(t-\tau)\right]^2\right|^2 dt
$$

or

$$
S(\tau) \propto \int
\left|E(t) + E(t-\tau)\right|^4 dt
$$

---

## How dispersion is applied to the pulse

The code works in the spectral domain.

If the initial spectral field is

$$
\tilde{E}_{\mathrm{in}}(\omega)
$$

then the code applies spectral phase as

$$
\tilde{E}_{\mathrm{out}}(\omega)
=
\tilde{E}_{\mathrm{in}}(\omega)
\exp\left[i\phi(\omega)\right]
$$

where \(\phi(\omega)\) is the total spectral phase from all optical components.

The time domain pulse is then obtained using an inverse Fourier transform:

$$
E_{\mathrm{out}}(t)
=
\mathcal{F}^{-1}
\left[
\tilde{E}_{\mathrm{out}}(\omega)
\right]
$$

In the code, this is done by

```matlab
E_omega = E_omega_initial .* exp(1i .* PHI_TOTAL);
E_t = fftshift(ifft(ifftshift(E_omega)));
