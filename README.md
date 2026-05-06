# Fringe Resolved SHG Interferometric Autocorrelation Simulator

A MATLAB forward simulator for fringe resolved second harmonic generation, SHG, interferometric autocorrelation of ultrafast laser pulses.

This code helps visualize how an ultrafast pulse and its autocorrelation trace change when the pulse accumulates dispersion from optical components between the laser source and the autocorrelator.

It can be used as a learning tool, debugging tool, or forward model for understanding why a measured fringe resolved autocorrelation trace may look different from an ideal transform limited pulse.

---

## Purpose

Short ultrafast pulses are very sensitive to dispersion.

Even if the pulse is close to transform limited at the laser output, the measured autocorrelation trace can change after the pulse passes through optical components such as:

- chirped mirrors
- dielectric mirrors
- Bragg mirrors
- air
- glass
- compressor optics
- nonlinear crystal or substrate inside the autocorrelator
- any other optical element in the beam path

This simulator lets the user include these phase contributions and see how the fringe resolved SHG interferometric autocorrelation trace changes.

---

## What this code does

The code can start from either:

- a measured laser spectrum
- a Gaussian temporal pulse
- a sech temporal pulse
- a super Gaussian temporal pulse
- a user defined custom temporal pulse

Then it applies spectral phase from optical components.

The final pulse is used to calculate the fringe resolved SHG interferometric autocorrelation trace.

The main model is

```math
S(\tau) \propto \int_{-\infty}^{\infty}
\left|E(t) + E(t-\tau)\right|^4 dt
```

where `E(t)` is the electric field of the pulse and `tau` is the delay between two pulse replicas.

This expression comes from the SHG field being proportional to the square of the total electric field:

```math
E_{2\omega}(t,\tau)
\propto
\left[E(t) + E(t-\tau)\right]^2
```

The detected SHG signal is proportional to the time integrated intensity:

```math
S(\tau)
\propto
\int
\left|E_{2\omega}(t,\tau)\right|^2 dt
```

Therefore,

```math
S(\tau)
\propto
\int
\left|\left[E(t) + E(t-\tau)\right]^2\right|^2 dt
```

or

```math
S(\tau)
\propto
\int
\left|E(t) + E(t-\tau)\right|^4 dt
```

---

## How dispersion is applied to the pulse

The code works in the spectral domain.

If the initial spectral field is

```math
\tilde{E}_{\mathrm{in}}(\omega)
```

then the code applies spectral phase as

```math
\tilde{E}_{\mathrm{out}}(\omega)
=
\tilde{E}_{\mathrm{in}}(\omega)
\exp\left[i\phi(\omega)\right]
```

where `phi(omega)` is the total spectral phase from all optical components.

The time domain pulse is then obtained using an inverse Fourier transform:

```math
E_{\mathrm{out}}(t)
=
\mathcal{F}^{-1}
\left[
\tilde{E}_{\mathrm{out}}(\omega)
\right]
```

In the code, this is done by

```matlab
E_omega = E_omega_initial .* exp(1i .* PHI_TOTAL);
E_t = fftshift(ifft(ifftshift(E_omega)));
```

The optical carrier is then added back as

```matlab
E1 = U .* exp(1i .* omega_carrier .* T);
```

So the electric fields used in the autocorrelation movie include the applied spectral phase.

---

## Spectral phase expansion

Manual dispersion terms are applied using a Taylor expansion around the carrier angular frequency.

The carrier angular frequency is

```math
\omega_0
```

The detuning from the carrier is

```math
\Delta\omega = \omega - \omega_0
```

The spectral phase can be written as

```math
\phi(\omega)
=
\phi(\omega_0)
+
GD(\omega_0)\Delta\omega
+
\frac{GDD}{2!}\Delta\omega^2
+
\frac{TOD}{3!}\Delta\omega^3
+
\frac{FOD}{4!}\Delta\omega^4
+
\frac{5OD}{5!}\Delta\omega^5
+
\frac{6OD}{6!}\Delta\omega^6
```

For pulse shape changes, the most important terms are usually

```math
\frac{GDD}{2!}\Delta\omega^2
+
\frac{TOD}{3!}\Delta\omega^3
+
\frac{FOD}{4!}\Delta\omega^4
+
\cdots
```

The constant phase mostly changes the absolute carrier phase. The linear phase mostly shifts the pulse in time. The higher order terms change the pulse duration, asymmetry, and detailed temporal structure.

In the code, this is implemented as

```matlab
domega = omega - omega0;

PHI_manual = ...
    GDD     .* domega.^2 ./ factorial(2) + ...
    TOD     .* domega.^3 ./ factorial(3) + ...
    FOD     .* domega.^4 ./ factorial(4) + ...
    FifthOD .* domega.^5 ./ factorial(5) + ...
    SixthOD .* domega.^6 ./ factorial(6);
```

In some versions of the code, the variable may be named `w` instead of `domega`. In that case, `w` means `omega - omega0`, not the absolute angular frequency.

---

## Manufacturer GD and GDD data

The code can also use manufacturer provided dispersion data.

If the manufacturer provides group delay versus wavelength, the code converts wavelength to angular frequency and integrates group delay to get spectral phase:

```math
\phi(\omega) = \int GD(\omega) d\omega
```

If the manufacturer provides GDD versus wavelength, the code integrates twice:

```math
GD(\omega) = \int GDD(\omega) d\omega
```

and then

```math
\phi(\omega) = \int GD(\omega) d\omega
```

This allows the user to include realistic wavelength dependent phase instead of only constant GDD and TOD values.

---

## Reference wavelength note

Manufacturer provided dispersion coefficients such as GDD and TOD are often specified at a reference wavelength, commonly 800 nm.

If the simulated pulse is centered at another wavelength, the user should convert the coefficient to the simulation carrier frequency.

A first order correction is

```math
GDD(\omega_0)
\approx
GDD(\omega_{\mathrm{ref}})
+
TOD(\omega_{\mathrm{ref}})
\left(\omega_0-\omega_{\mathrm{ref}}\right)
```

Here `omega` must be in rad/fs if GDD is in fs² and TOD is in fs³.

For example, if the manufacturer gives GDD and TOD at 800 nm but the pulse is centered at 758 nm:

```math
\omega_{\mathrm{ref}}
=
\frac{2\pi c}{800\ \mathrm{nm}}
```

```math
\omega_0
=
\frac{2\pi c}{758\ \mathrm{nm}}
```

```math
GDD_{758}
\approx
GDD_{800}
+
TOD_{800}
(\omega_0-\omega_{\mathrm{ref}})
```

---

## Material dispersion

A useful public source for refractive index data, Sellmeier coefficients, GVD, and material dispersion is:

https://refractiveindex.info/

Users can use Sellmeier coefficients to calculate GVD, TOD, and higher order dispersion terms when these values are not directly provided by a manufacturer.

---

## Example input files

This repository includes example input files:

```text
Spectrum.xlsx
chirped_mirror.xlsx
reflecting_mirror.xlsx
```

These files demonstrate how to provide:

- measured spectral intensity versus wavelength
- manufacturer group delay versus wavelength
- manufacturer GDD versus wavelength

Users can replace these files with their own measured or manufacturer provided data.

---

## Input types

Choose the input type near the beginning of the MATLAB file:

```matlab
input_type = 'spectrum';
```

Available options are:

```matlab
input_type = 'spectrum';
input_type = 'gaussian';
input_type = 'sech';
input_type = 'supergaussian';
input_type = 'custom_temporal';
```

Only the selected input block is active. Other input blocks are ignored.

---

## Adding optical components

Optical components are defined using the `optics` structure.

For example, to add a new component with known GDD and TOD:

```matlab
optics(5).name = 'Additional glass component';

optics(5).use_manual_dispersion = true;
optics(5).GDD_fs2 = 50;
optics(5).TOD_fs3 = 100;
optics(5).FOD_fs4 = NaN;
optics(5).FifthOD_fs5 = NaN;
optics(5).SixthOD_fs6 = NaN;

optics(5).use_GD_file = false;
optics(5).GD_file = '';
optics(5).GD_lambda_col = 1;
optics(5).GD_col = 2;
optics(5).GD_multiplier = 1;

optics(5).use_GDD_file = false;
optics(5).GDD_file = '';
optics(5).GDD_lambda_col = 1;
optics(5).GDD_col = 2;
optics(5).GDD_multiplier = 1;
```

The code automatically includes all optics defined as

```matlab
optics(1)
optics(2)
optics(3)
...
```

because the engine loops through

```matlab
for k = 1:length(optics)
```

---

## Dispersion input methods

For each optic, normally use only one method.

Use manual coefficients if GDD, TOD, FOD, or higher order values are known:

```matlab
use_manual_dispersion = true
```

Use a GD file if the manufacturer provides group delay versus wavelength:

```matlab
use_GD_file = true
```

Use a GDD file if the manufacturer provides GDD versus wavelength:

```matlab
use_GDD_file = true
```

If more than one method is turned on for the same optic, the code adds the phase contributions together and gives a warning.

Manual dispersion coefficients are entered as total values:

```matlab
GDD_fs2
TOD_fs3
FOD_fs4
FifthOD_fs5
SixthOD_fs6
```

Empty or `NaN` values are treated as zero.

---

## Multipliers

The multiplier is used when manufacturer data is given per bounce, per reflection, or per pass.

Example:

```matlab
optics(1).GD_multiplier = 8;
```

means the chirped mirror group delay contribution is applied 8 times.

```matlab
optics(2).GDD_multiplier = 4;
```

means the mirror GDD contribution is applied 4 times.

Manual GDD, TOD, and higher order values are treated as total values entered by the user.

---

## Air propagation

The code includes an optional air dispersion contribution.

The user can enter the air path length in meters:

```matlab
air_path_length_m = 2.06;
```

and the GDD per meter:

```matlab
air_GDD_per_meter_fs2 = 23.781;
```

The total air GDD is then

```math
GDD_{\mathrm{air,total}}
=
GDD_{\mathrm{air,per\ meter}}
\times
L_{\mathrm{air}}
```

Higher order air dispersion terms can also be entered if known.

---

## Background free intensity autocorrelation

The code can calculate the background free intensity autocorrelation.

For simulation, the most robust method is direct envelope autocorrelation:

```math
S_{\mathrm{IAC}}(\tau)
=
\int
I(t)I(t-\tau)dt
```

where

```math
I(t)=|U(t)|^2
```

This is more stable than extracting the low frequency part from a fringe resolved trace, especially for few cycle pulses where Fourier filtering can become difficult.

---

## Running the code

1. Open MATLAB.
2. Put the `.m` file and example `.xlsx` files in the same folder.
3. Open the main file:

```text
fringe_resolved_shg_autocorrelation_simulator.m
```

4. Choose the input type.
5. Edit the optical components and air path if needed.
6. Run the script.

The code will generate the autocorrelation trace and save output files in the output folder.

---

## Recommended default settings

For normal use:

```matlab
show_movie = false;
plot_diagnostics = false;
plot_basic_results = true;
```

For learning or debugging:

```matlab
show_movie = true;
plot_diagnostics = true;
```

---

## Output files

The code can save:

```text
SHG_autocorrelation_basic_results.png
SHG_autocorrelation_diagnostic_plots.png
SHG_autocorrelation_trace_results.xlsx
SHG_autocorrelation_spectral_field_results.xlsx
```

The output includes the fringe resolved SHG autocorrelation trace and the background free intensity autocorrelation.

---

## What this code is not

This code is not a replacement for full pulse retrieval methods such as:

- FROG
- SPIDER
- d-scan
- MIIPS

It is a forward simulator. It shows the expected autocorrelation trace from a given input pulse and a given set of dispersion terms.

It does not uniquely retrieve the full electric field from an experimental trace.

---

## License

This project is released under the MIT License.

You are free to use, modify, and share the code with attribution.

---

## Author

Asad Mahmood  
PhD Physics researcher  
University of Nebraska Lincoln  
Ultrafast optics, nonlinear optics, and optical pulse characterization  

GitHub: AsadOptics  
LinkedIn: https://www.linkedin.com/in/asad-mahmood-a3313228a/
