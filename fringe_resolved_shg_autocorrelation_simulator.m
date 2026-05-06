clearvars;
close all;
clc;

%% ============================================================
%  FRINGE RESOLVED SHG INTERFEROMETRIC AUTOCORRELATION SIMULATOR
%
%  Author: Asad Mahmood
%  LinkedIn:
%  GitHub:
%% ============================================================

%% ============================================================
%  Purpose:
%  Simulate a fringe resolved second harmonic generation, SHG,
%  interferometric autocorrelation trace for ultrafast laser pulses.
%
%  This is a general forward simulator for nonlinear interferometric
%  autocorrelation. It is not tied to any specific commercial
%  autocorrelator.
%
%  The user can start from:
%       1. Measured laser spectrum
%       2. Temporal Gaussian pulse
%       3. Temporal sech pulse
%       4. Temporal super Gaussian pulse
%       5. Custom temporal pulse
%
%  The user can add optical phase from:
%       1. Manual dispersion coefficients:
%          GDD, TOD, FOD, fifth order, sixth order
%       2. Manufacturer GD versus wavelength data
%       3. Manufacturer GDD versus wavelength data
%       4. Air propagation
%       5. Autocorrelator nonlinear crystal or substrate dispersion
%       6. Any additional optics
%
%  Units:
%       wavelength      nm
%       angular freq    rad/fs
%       time            fs
%       GD              fs
%       GDD             fs^2
%       TOD             fs^3
%       FOD             fs^4
%       fifth order     fs^5
%       sixth order     fs^6
%
%  Main SHG interferometric autocorrelation model:
%
%       E_total(t,tau) = E(t) + E(t - tau)
%
%       P_2w(t,tau) proportional to [E_total(t,tau)]^2
%
%       S(tau) proportional to integral |P_2w(t,tau)|^2 dt
%
%       Therefore:
%
%       S(tau) proportional to integral |E(t) + E(t - tau)|^4 dt
%
%% ============================================================
%  Helpful source for material dispersion:
%       https://refractiveindex.info/
%
%  This website provides refractive index data, Sellmeier coefficients,
%  and in many cases group velocity dispersion, GVD, for optical materials.
%  Users can use Sellmeier coefficients to calculate GVD, TOD, and higher
%  order dispersion terms if these values are not directly provided by a
%  manufacturer.





%% ============================================================
%  SECTION 1
%  MASTER INPUT SELECTION
%
%  USER SHOULD EDIT THIS SECTION
%% ============================================================

c_nm_per_fs = 299.792458;

% =============================================================
% CHOOSE ONLY ONE INPUT TYPE
%
% Available options:
%
%   'spectrum'
%       Use measured laser spectral intensity from Excel or CSV.
%       The code converts I(lambda) to I(omega), builds spectral
%       amplitude, then applies spectral phase.
%
%   'gaussian'
%       Start from an ideal Gaussian temporal electric field.
%
%   'sech'
%       Start from an ideal sech temporal electric field.
%
%   'supergaussian'
%       Start from an ideal super Gaussian temporal electric field.
%
%   'custom_temporal'
%       Start from a user defined complex temporal electric field.
%
% IMPORTANT:
% Only the block matching input_type is active.
% All other input blocks are ignored automatically.
% =============================================================

input_type = 'gaussian';
% input_type = 'spectrum';
% input_type = 'sech';
% input_type = 'supergaussian';
% input_type = 'custom_temporal';


%% ============================================================
%  SECTION 2
%  SETTINGS USED BY ALL INPUT TYPES
%
%  USER CAN EDIT THIS SECTION
%% ============================================================

% Number of points used in FFT grid.
% Larger value gives better resolution but slower calculation.
Nw = 2^14;

% Delay range for autocorrelation, fs.
delay_min_fs = -160;
delay_max_fs = 160;
n_delay = 2000;

% Fine temporal interpolation grid used during autocorrelation.
% Increase if optical fringes look under sampled.
Nt_fine = 200000;

% Movie option.
show_movie = true;
movie_update_every = 10;

% Movie plot mode.
% Options:
%   'field'    shows real electric field oscillations
%   'envelope' shows intensity envelope only
movie_plot_mode = 'field';

% Plot options.
% Basic plots are the main user friendly outputs.
plot_basic_results = true;

% Diagnostic plots show spectrum, spectral phase, temporal intensity,
% Fringe Resolved SHG Autocorrelator trace, intensity AC, and FFT. Usually keep false for clean output.
plot_diagnostics = true;

% Save output files?
save_figures = false;
output_folder = 'SHG_autocorrelation_outputs';

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Background free intensity autocorrelation extraction method.
%
% 'direct_envelope'
%     Recommended. Calculates intensity autocorrelation directly from
%     the pulse envelope I(t). This is clean and robust, especially for
%     few cycle pulses.
%
% 'fourier_filter'
%     Extracts low frequency component from fringe resolved autocorrelation.
%     This mimics experimental post processing, but can fail for few cycle pulses.
%
intensity_ac_method = 'direct_envelope';
% intensity_ac_method = 'fourier_filter';


%% ============================================================
%  SECTION 3A
%  ACTIVE ONLY IF input_type = 'spectrum'
%
%  USER SHOULD EDIT THIS SECTION ONLY FOR MEASURED SPECTRUM INPUT
%% ============================================================

% This section is ignored when input_type is gaussian, sech,
% supergaussian, or custom_temporal.

spectrum_file = 'Spectrum.xlsx';

% Column numbers in the spectrum file.
spectrum_lambda_col = 1;
spectrum_intensity_col = 2;

% Crop measured spectrum in wavelength, nm.
% Use this to remove noisy spectrum edges.
lambda_min_nm = 650;
lambda_max_nm = 950;

% Number of points after interpolation to uniform omega grid.
Nw_spectrum = Nw;


%% ============================================================
%  SECTION 3B
%  ACTIVE ONLY IF input_type = 'gaussian', 'sech',
%  'supergaussian', or 'custom_temporal'
%
%  USER SHOULD EDIT THIS SECTION ONLY FOR TEMPORAL PULSE INPUT
%% ============================================================

% This section is ignored when input_type = 'spectrum'.

% Central wavelength for temporal pulse options, nm.
lambda0_nm = 800;

% Angular frequency center for temporal pulse options.
omega0_default = 2*pi*c_nm_per_fs/lambda0_nm;

% Time window for directly generated temporal pulses, fs.
% Make this much larger than the pulse duration.
Tmax_fs = 500;

% Temporal grid.
t = linspace(-Tmax_fs, Tmax_fs, Nw);
dt = mean(diff(t));

% Corresponding angular frequency grid for temporal pulse options.
dw = 2*pi/(Nw*dt);
w_temporal = (-Nw/2:Nw/2-1)*dw;
omega_temporal = omega0_default + w_temporal;

% Pulse duration for ideal temporal pulses.
% This is intensity FWHM, not field amplitude FWHM.
pulse_fwhm_fs = 20;

% Used only when input_type = 'supergaussian'.
supergaussian_order = 4;

% Optional temporal phase for gaussian, sech, and supergaussian.
% Keep zero unless you intentionally want temporal chirp.
temporal_phase = zeros(size(t));

% Used only when input_type = 'custom_temporal'.
% Define your own complex field on the same time grid t.
%
% Example:
% custom_E_t = exp(-2*log(2)*(t/pulse_fwhm_fs).^2);
%
% Example with temporal phase:
% custom_E_t = exp(-2*log(2)*(t/pulse_fwhm_fs).^2) .* exp(1i*0.001*t.^2);
%
custom_E_t = [];


%% ============================================================
%  SECTION 4
%  DISPLAY ACTIVE INPUT SETTINGS
%
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

fprintf('\n============================================================\n');
fprintf('FRINGE RESOLVED SHG AUTOCORRELATION SIMULATOR SETUP\n');
fprintf('============================================================\n');
fprintf('Selected input_type: %s\n', input_type);

switch lower(input_type)

    case 'spectrum'
        fprintf('Active input block: SECTION 3A, measured spectrum input\n');
        fprintf('Spectrum file: %s\n', spectrum_file);
        fprintf('Using wavelength column: %d\n', spectrum_lambda_col);
        fprintf('Using intensity column: %d\n', spectrum_intensity_col);
        fprintf('Spectrum crop: %.2f nm to %.2f nm\n', lambda_min_nm, lambda_max_nm);
        fprintf('Ignored block: SECTION 3B temporal pulse settings\n');

    case 'gaussian'
        fprintf('Active input block: SECTION 3B, Gaussian temporal pulse\n');
        fprintf('Central wavelength: %.3f nm\n', lambda0_nm);
        fprintf('Pulse intensity FWHM: %.3f fs\n', pulse_fwhm_fs);
        fprintf('Time window: %.3f fs to %.3f fs\n', -Tmax_fs, Tmax_fs);
        fprintf('Ignored block: SECTION 3A measured spectrum settings\n');

    case 'sech'
        fprintf('Active input block: SECTION 3B, sech temporal pulse\n');
        fprintf('Central wavelength: %.3f nm\n', lambda0_nm);
        fprintf('Pulse intensity FWHM: %.3f fs\n', pulse_fwhm_fs);
        fprintf('Time window: %.3f fs to %.3f fs\n', -Tmax_fs, Tmax_fs);
        fprintf('Ignored block: SECTION 3A measured spectrum settings\n');

    case 'supergaussian'
        fprintf('Active input block: SECTION 3B, super Gaussian temporal pulse\n');
        fprintf('Central wavelength: %.3f nm\n', lambda0_nm);
        fprintf('Pulse intensity FWHM parameter: %.3f fs\n', pulse_fwhm_fs);
        fprintf('Super Gaussian order: %.3f\n', supergaussian_order);
        fprintf('Time window: %.3f fs to %.3f fs\n', -Tmax_fs, Tmax_fs);
        fprintf('Ignored block: SECTION 3A measured spectrum settings\n');

    case 'custom_temporal'
        fprintf('Active input block: SECTION 3B, custom temporal field\n');
        fprintf('Central wavelength: %.3f nm\n', lambda0_nm);
        fprintf('Time window: %.3f fs to %.3f fs\n', -Tmax_fs, Tmax_fs);
        fprintf('custom_E_t must be defined by the user.\n');
        fprintf('Ignored block: SECTION 3A measured spectrum settings\n');

    otherwise
        error('Unknown input_type. Use spectrum, gaussian, sech, supergaussian, or custom_temporal.');
end

fprintf('Delay range: %.3f fs to %.3f fs\n', delay_min_fs, delay_max_fs);
fprintf('Number of delay points: %d\n', n_delay);
fprintf('Movie mode: %d\n', show_movie);
fprintf('Movie plot mode: %s\n', movie_plot_mode);
fprintf('Basic plots: %d\n', plot_basic_results);
fprintf('Diagnostic plots: %d\n', plot_diagnostics);
fprintf('============================================================\n\n');


%% ============================================================
%  SECTION 4B
%  INPUT VALIDATION
%
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

valid_input_types = {'spectrum','gaussian','sech','supergaussian','custom_temporal'};

if ~ismember(lower(input_type), valid_input_types)
    error('Invalid input_type. Choose spectrum, gaussian, sech, supergaussian, or custom_temporal.');
end

if strcmpi(input_type, 'spectrum')
    if isempty(spectrum_file)
        error('input_type is spectrum, but spectrum_file is empty.');
    end
end

if strcmpi(input_type, 'custom_temporal')
    if isempty(custom_E_t)
        error('input_type is custom_temporal, but custom_E_t is empty.');
    end

    if length(custom_E_t) ~= length(t)
        error('custom_E_t must have the same length as the time grid t.');
    end
end

if any(strcmpi(input_type, {'gaussian','sech','supergaussian','custom_temporal'}))
    if lambda0_nm <= 0
        error('lambda0_nm must be positive for temporal pulse input.');
    end

    if Tmax_fs <= 0
        error('Tmax_fs must be positive for temporal pulse input.');
    end
end


%% ============================================================
%  SECTION 5
%  OPTICAL DISPERSION SETTINGS
%
%  USER SHOULD EDIT THIS SECTION
%
%  IMPORTANT RULE:
%  For each optic, normally use only ONE of the following:
%
%       use_manual_dispersion = true
%       use_GD_file = true
%       use_GDD_file = true
%
%  If more than one is true for the same optic, the code adds them
%  together and gives a warning.
%
%  Meaning of multiplier:
%
%       GD_multiplier:
%           Number of times GD file contribution is applied.
%           Example: manufacturer GD is per chirped mirror bounce.
%           If pulse has 6 bounces, use GD_multiplier = 6.
%
%       GDD_multiplier:
%           Number of times GDD file contribution is applied.
%           Example: manufacturer GDD is per reflection.
%           If beam reflects from 4 mirrors, use GDD_multiplier = 4.
%
%% ============================================================

optics = struct([]);


% =============================================================
%  Optic 1: Chirped mirror
% =============================================================

optics(1).name = 'Chirped mirror';

% Option A: manual dispersion coefficients.
% Use this only if you know the total GDD, TOD, FOD, etc.
optics(1).use_manual_dispersion = false;
optics(1).GDD_fs2 = NaN;
optics(1).TOD_fs3 = NaN;
optics(1).FOD_fs4 = NaN;
optics(1).FifthOD_fs5 = NaN;
optics(1).SixthOD_fs6 = NaN;

% Option B: manufacturer GD versus wavelength file.
% This is usually best for chirped mirrors.
optics(1).use_GD_file = false;
optics(1).GD_file = 'chirped_mirror.xlsx';
optics(1).GD_lambda_col = 1;
optics(1).GD_col = 2;

% If manufacturer GD is per bounce, put number of bounces here.
% If the GD file already represents the total path, keep this 1.
optics(1).GD_multiplier = 2; % Bounces

% Option C: manufacturer GDD versus wavelength file.
% Usually not needed if GD file is already used.
optics(1).use_GDD_file = false;
optics(1).GDD_file = '';
optics(1).GDD_lambda_col = 1;
optics(1).GDD_col = 2;
optics(1).GDD_multiplier = 1;


% =============================================================
%  Optic 2: Reflecting mirrors
% =============================================================

optics(2).name = 'Reflecting mirrors';

% Option A: manual total reflecting mirror dispersion.
optics(2).use_manual_dispersion = false;
optics(2).GDD_fs2 = NaN;
optics(2).TOD_fs3 = NaN;
optics(2).FOD_fs4 = NaN;
optics(2).FifthOD_fs5 = NaN;
optics(2).SixthOD_fs6 = NaN;

% Option B: manufacturer GD versus wavelength file.
optics(2).use_GD_file = false;
optics(2).GD_file = '';
optics(2).GD_lambda_col = 1;
optics(2).GD_col = 2;
optics(2).GD_multiplier = 1;

% Option C: manufacturer GDD versus wavelength file.
optics(2).use_GDD_file = false;
optics(2).GDD_file = 'reflecting_mirror.xlsx';
optics(2).GDD_lambda_col = 1;
optics(2).GDD_col = 2;

% If GDD file is per reflection and beam has 4 reflections, use 4.
optics(2).GDD_multiplier = 4;


% =============================================================
%  Optic 3: Autocorrelator's internal crystal
% =============================================================

optics(3).name = 'Autocorrelator nonlinear crystal or substrate';
% User can enter GVD times thickness directly as GDD. Nonlinear crystal is
% usually too thin ~70 microns so ignored. But its substrate is pretty
% thick and typically made of Fused Silica. Always check your
% autocorrelator's manufacturer specs for details.

% Important note:
% Manufacturer-provided dispersion coefficients such as GDD and TOD are
% usually specified at a reference wavelength, often 800 nm.
%
% In this code, manual dispersion coefficients are applied around the
% simulation carrier frequency omega0. Therefore, if a coefficient is given
% at another reference frequency omega_ref, the user should convert it to
% the value at omega0 before entering it.
%
% First-order approximation:
%
%     GDD(omega0) = GDD(omega_ref) + TOD(omega_ref)*(omega0 - omega_ref)
%
% Example:
% If the manufacturer gives GDD and TOD at 800 nm, but the simulated pulse
% is centered at 758 nm, then:
%
%     omega_ref = 2*pi*c/800 nm
%     omega0    = 2*pi*c/758 nm
%
%     GDD_at_758nm = GDD_at_800nm + TOD_at_800nm*(omega0 - omega_ref)
%
% Make sure omega is in rad/fs if GDD is in fs^2 and TOD is in fs^3.

optics(3).use_manual_dispersion = false;
optics(3).GDD_fs2 = 274.3785;
optics(3).TOD_fs3 = 345;
optics(3).FOD_fs4 = NaN;
optics(3).FifthOD_fs5 = NaN;
optics(3).SixthOD_fs6 = NaN;

optics(3).use_GD_file = false;
optics(3).GD_file = '';
optics(3).GD_lambda_col = 1;
optics(3).GD_col = 2;
optics(3).GD_multiplier = 1;

optics(3).use_GDD_file = false;
optics(3).GDD_file = '';
optics(3).GDD_lambda_col = 1;
optics(3).GDD_col = 2;
optics(3).GDD_multiplier = 1;


% =============================================================
%  Optic 4: Unknown extra dispersion
% =============================================================

optics(4).name = 'Unknown extra dispersion';

% This is useful if you want to test an additional unknown GDD/TOD or
% higher orders. For instance, including all optics on the table still does
% not generate expected autocorrelation, then it is good time to add some
% GDD and TOD (and maybe FOD) to see if results start matching.
% This is optional and should not be used as proof of a unique physical cause.
% It is only a sensitivity test for missing or uncertain dispersion.
optics(4).use_manual_dispersion = false;
optics(4).GDD_fs2 = 136;
optics(4).TOD_fs3 = NaN;
optics(4).FOD_fs4 = NaN;
optics(4).FifthOD_fs5 = NaN;
optics(4).SixthOD_fs6 = NaN;

optics(4).use_GD_file = false;
optics(4).GD_file = '';
optics(4).GD_lambda_col = 1;
optics(4).GD_col = 2;
optics(4).GD_multiplier = 1;

optics(4).use_GDD_file = false;
optics(4).GDD_file = '';
optics(4).GDD_lambda_col = 1;
optics(4).GDD_col = 2;
optics(4).GDD_multiplier = 1;


% =============================================================
%  Optic 5: Additional component
% =============================================================

optics(5).name = 'Additional component'; % if any, like entrance window, lens, filter etc.

% Use manual dispersion if GDD, TOD, FOD, etc. are known.
optics(5).use_manual_dispersion = false;

optics(5).GDD_fs2 = NaN;      % fs^2
optics(5).TOD_fs3 = NaN;     % fs^3
optics(5).FOD_fs4 = NaN;     % fs^4
optics(5).FifthOD_fs5 = NaN; % fs^5
optics(5).SixthOD_fs6 = NaN; % fs^6

% Keep GD file off if using manual coefficients.
optics(5).use_GD_file = false;
optics(5).GD_file = '';
optics(5).GD_lambda_col = 1;
optics(5).GD_col = 2;
optics(5).GD_multiplier = 1;

% Keep GDD file off if using manual coefficients.
optics(5).use_GDD_file = false;
optics(5).GDD_file = '';
optics(5).GDD_lambda_col = 1;
optics(5).GDD_col = 2;
optics(5).GDD_multiplier = 1;


%% ============================================================
%  SECTION 6
%  AIR DISPERSION SETTINGS
%
%  USER CAN EDIT THIS SECTION
%% ============================================================

use_air = false;

% Effective air GDD.
% Change if you know a more accurate value.
air_GDD_per_meter_fs2 = 23.781; % It is GVD so GDD=GVD*z.

% Air path length between laser and autocorrelator, meters.
air_path_length_m = 2.41;

% If you know higher order air dispersion, enter it here.
% Otherwise keep NaN.
air_TOD_per_meter_fs3 = NaN;
air_FOD_per_meter_fs4 = NaN;
air_FifthOD_per_meter_fs5 = NaN;
air_SixthOD_per_meter_fs6 = NaN;


%% ============================================================
%  SECTION 7
%  BUILD INITIAL FIELD
%
%  ENGINE SECTION
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

switch lower(input_type)

    case 'spectrum'

        data = readmatrix(spectrum_file);

        lambda_nm = data(:, spectrum_lambda_col).';
        intensity_lambda = data(:, spectrum_intensity_col).';

        valid = isfinite(lambda_nm) & isfinite(intensity_lambda);
        lambda_nm = lambda_nm(valid);
        intensity_lambda = intensity_lambda(valid);

        mask = lambda_nm >= lambda_min_nm & lambda_nm <= lambda_max_nm;
        lambda_nm = lambda_nm(mask);
        intensity_lambda = intensity_lambda(mask);

        intensity_lambda(intensity_lambda < 0) = 0;

        omega_raw = 2*pi*c_nm_per_fs ./ lambda_nm;

        % Convert spectral density from wavelength to angular frequency.
        % I_omega d omega = I_lambda d lambda
        % |d lambda / d omega| = lambda^2 / (2 pi c)
        intensity_omega_raw = intensity_lambda .* lambda_nm.^2 ./ (2*pi*c_nm_per_fs);

        [omega_raw, idx] = sort(omega_raw);
        intensity_omega_raw = intensity_omega_raw(idx);

        [omega_raw, idx_unique] = unique(omega_raw, 'stable');
        intensity_omega_raw = intensity_omega_raw(idx_unique);

        omega = linspace(min(omega_raw), max(omega_raw), Nw_spectrum);
        intensity_omega = interp1(omega_raw, intensity_omega_raw, omega, 'pchip', 0);

        intensity_omega(intensity_omega < 0) = 0;

        amp_omega = sqrt(intensity_omega);
        amp_omega = amp_omega ./ max(amp_omega);

        [~, idx_peak] = max(amp_omega);
        omega0 = omega(idx_peak);

        w = omega - omega0;

        E_omega_initial = amp_omega;

    case 'gaussian'

        omega0 = omega0_default;
        omega = omega_temporal;
        w = w_temporal;

        E_t_initial = exp(-2*log(2)*(t/pulse_fwhm_fs).^2) .* exp(1i*temporal_phase);
        E_t_initial = E_t_initial ./ max(abs(E_t_initial));

        E_omega_initial = fftshift(fft(ifftshift(E_t_initial)));
        E_omega_initial = E_omega_initial ./ max(abs(E_omega_initial));

    case 'sech'

        omega0 = omega0_default;
        omega = omega_temporal;
        w = w_temporal;

        % sech intensity FWHM relation:
        % I(t) = sech^2(t/T0)
        % FWHM = 1.763*T0
        T0 = pulse_fwhm_fs/1.763;

        E_t_initial = sech(t/T0) .* exp(1i*temporal_phase);
        E_t_initial = E_t_initial ./ max(abs(E_t_initial));

        E_omega_initial = fftshift(fft(ifftshift(E_t_initial)));
        E_omega_initial = E_omega_initial ./ max(abs(E_omega_initial));

    case 'supergaussian'

        omega0 = omega0_default;
        omega = omega_temporal;
        w = w_temporal;

        E_t_initial = exp(-0.5*(abs(t)/(pulse_fwhm_fs/2)).^(2*supergaussian_order)) ...
            .* exp(1i*temporal_phase);

        E_t_initial = E_t_initial ./ max(abs(E_t_initial));

        E_omega_initial = fftshift(fft(ifftshift(E_t_initial)));
        E_omega_initial = E_omega_initial ./ max(abs(E_omega_initial));

    case 'custom_temporal'

        omega0 = omega0_default;
        omega = omega_temporal;
        w = w_temporal;

        E_t_initial = custom_E_t;
        E_t_initial = E_t_initial ./ max(abs(E_t_initial));

        E_omega_initial = fftshift(fft(ifftshift(E_t_initial)));
        E_omega_initial = E_omega_initial ./ max(abs(E_omega_initial));

end

Nw = length(w);


%% ============================================================
%  SECTION 8
%  BUILD TOTAL SPECTRAL PHASE
%
%  ENGINE SECTION
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

PHI_TOTAL = zeros(size(w));
phase_report = {};

for k = 1:length(optics)

    optic = optics(k);

    n_methods = double(optic.use_manual_dispersion) + ...
        double(optic.use_GD_file) + ...
        double(optic.use_GDD_file);

    if n_methods > 1
        warning(['Optic "', optic.name, '" has more than one dispersion input method active. ', ...
            'Manual dispersion, GD file, and GDD file contributions will be added together. ', ...
            'Make sure this is intentional.']);
    end

    PHI_this = zeros(size(w));

    %% Manual dispersion
    if optic.use_manual_dispersion

        GDD = zero_if_empty_or_nan(optic.GDD_fs2);
        TOD = zero_if_empty_or_nan(optic.TOD_fs3);
        FOD = zero_if_empty_or_nan(optic.FOD_fs4);
        FifthOD = zero_if_empty_or_nan(optic.FifthOD_fs5);
        SixthOD = zero_if_empty_or_nan(optic.SixthOD_fs6);

        PHI_manual = ...
            GDD     .* w.^2 ./ factorial(2) + ...
            TOD     .* w.^3 ./ factorial(3) + ...
            FOD     .* w.^4 ./ factorial(4) + ...
            FifthOD .* w.^5 ./ factorial(5) + ...
            SixthOD .* w.^6 ./ factorial(6);

        PHI_this = PHI_this + PHI_manual;

        phase_report{end+1} = sprintf('%s manual: GDD %.3g fs^2, TOD %.3g fs^3, FOD %.3g fs^4, 5OD %.3g fs^5, 6OD %.3g fs^6', ...
            optic.name, GDD, TOD, FOD, FifthOD, SixthOD);
    end

    %% Manufacturer GD file
    if optic.use_GD_file

        if isempty(optic.GD_file)
            error(['GD file is empty for optic: ', optic.name]);
        end

        PHI_GD = phase_from_GD_file( ...
            optic.GD_file, ...
            optic.GD_lambda_col, ...
            optic.GD_col, ...
            omega, ...
            omega0, ...
            c_nm_per_fs);

        PHI_this = PHI_this + optic.GD_multiplier .* PHI_GD;

        phase_report{end+1} = sprintf('%s GD file used with multiplier %.3g', ...
            optic.name, optic.GD_multiplier);
    end

    %% Manufacturer GDD file
    if optic.use_GDD_file

        if isempty(optic.GDD_file)
            error(['GDD file is empty for optic: ', optic.name]);
        end

        PHI_GDD_file = phase_from_GDD_file( ...
            optic.GDD_file, ...
            optic.GDD_lambda_col, ...
            optic.GDD_col, ...
            omega, ...
            omega0, ...
            c_nm_per_fs);

        PHI_this = PHI_this + optic.GDD_multiplier .* PHI_GDD_file;

        phase_report{end+1} = sprintf('%s GDD file used with multiplier %.3g', ...
            optic.name, optic.GDD_multiplier);
    end

    PHI_TOTAL = PHI_TOTAL + PHI_this;
end


%% ============================================================
%  SECTION 9
%  ADD AIR PHASE
%
%  ENGINE SECTION
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

if use_air

    air_GDD = zero_if_empty_or_nan(air_GDD_per_meter_fs2) * air_path_length_m;
    air_TOD = zero_if_empty_or_nan(air_TOD_per_meter_fs3) * air_path_length_m;
    air_FOD = zero_if_empty_or_nan(air_FOD_per_meter_fs4) * air_path_length_m;
    air_FifthOD = zero_if_empty_or_nan(air_FifthOD_per_meter_fs5) * air_path_length_m;
    air_SixthOD = zero_if_empty_or_nan(air_SixthOD_per_meter_fs6) * air_path_length_m;

    PHI_air = ...
        air_GDD     .* w.^2 ./ factorial(2) + ...
        air_TOD     .* w.^3 ./ factorial(3) + ...
        air_FOD     .* w.^4 ./ factorial(4) + ...
        air_FifthOD .* w.^5 ./ factorial(5) + ...
        air_SixthOD .* w.^6 ./ factorial(6);

    PHI_TOTAL = PHI_TOTAL + PHI_air;

    phase_report{end+1} = sprintf('Air: length %.3g m, GDD %.3g fs^2, TOD %.3g fs^3, FOD %.3g fs^4, 5OD %.3g fs^5, 6OD %.3g fs^6', ...
        air_path_length_m, air_GDD, air_TOD, air_FOD, air_FifthOD, air_SixthOD);
end


%% ============================================================
%  SECTION 10
%  RECONSTRUCT TEMPORAL PULSE
%
%  ENGINE SECTION
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

E_omega = E_omega_initial .* exp(1i .* PHI_TOTAL);

E_t = fftshift(ifft(ifftshift(E_omega)));
E_t = E_t ./ max(abs(E_t));

% Build time axis from omega grid.
dw = mean(diff(w));
dt = 2*pi/(Nw*dw);
t_recon = (-Nw/2:Nw/2-1)*dt;

% Center pulse around peak.
[~, peak_idx] = max(abs(E_t));
t_recon = t_recon - t_recon(peak_idx);

% Crop useful region.
crop_half_width_fs = max(300, 2*max(abs([delay_min_fs delay_max_fs])));

crop_mask = t_recon >= -crop_half_width_fs & t_recon <= crop_half_width_fs;
t_crop = t_recon(crop_mask);
E_crop = E_t(crop_mask);

if length(t_crop) < 20
    error('Time crop is too small. Increase crop_half_width_fs or check frequency grid.');
end

% Fine time grid for autocorrelation.
T = linspace(min(t_crop), max(t_crop), Nt_fine);
U = interp1(t_crop, E_crop, T, 'pchip', 0);
U = U ./ max(abs(U));


%% ============================================================
%  SECTION 11
%  FRINGE RESOLVED SHG INTERFEROMETRIC AUTOCORRELATION
%
%  ENGINE SECTION
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

tau_fs = linspace(delay_min_fs, delay_max_fs, n_delay);

% Use carrier from actual spectral center.
omega_carrier = omega0;

E1 = U .* exp(1i .* omega_carrier .* T);

auto_corr = zeros(size(tau_fs));

if show_movie
    figMovie = figure('Color','w');
    figMovie.WindowState = 'maximized';

    tileMovie = tiledlayout(figMovie,1,2);
    tileMovie.Padding = 'compact';
    tileMovie.TileSpacing = 'compact';
end

for i = 1:length(tau_fs)

    tau = tau_fs(i);

    % Physical delay. No circular wrapping.
    E2 = interp1(T, E1, T - tau, 'linear', 0);

    % Correct fringe resolved SHG autocorrelation signal:
    % P_2w proportional to (E1 + E2)^2
    % Signal proportional to integral |P_2w|^2 dt
    SH_field = (E1 + E2).^2;
    auto_corr(i) = trapz(T, abs(SH_field).^2);

    if show_movie && mod(i, movie_update_every) == 0

        current_tau = tau_fs(1:i);
        current_ac = auto_corr(1:i);

        if strcmpi(movie_plot_mode, 'field')

            E1_plot = real(E1);
            E2_plot = real(E2);

            env1 = abs(U);
            env2 = abs(E2);

            env_total = env1 + env2;
            threshold = 0.03 * max(env_total);
            active_idx = find(env_total > threshold);

            if isempty(active_idx)
                x_left = min(T);
                x_right = max(T);
            else
                x_left = T(active_idx(1));
                x_right = T(active_idx(end));

                padding = 0.15 * (x_right - x_left);
                if padding == 0
                    padding = 20;
                end

                x_left = x_left - padding;
                x_right = x_right + padding;
            end

            x_left = max(x_left, min(T));
            x_right = min(x_right, max(T));

            y_field_max = max(abs([E1_plot(:); E2_plot(:)]));
            if y_field_max == 0
                y_field_max = 1;
            end

            nexttile(1);
            plot(T, E1_plot, 'LineWidth', 1.2);
            hold on;
            plot(T, E2_plot, 'LineWidth', 1.2);
            hold off;
            xlim([x_left x_right]);
            ylim([-1.15*y_field_max 1.15*y_field_max]);
            xlabel('Time (fs)');
            ylabel('Electric field, a.u.');
            title(['Two delayed electric fields, delay = ', num2str(tau, '%.2f'), ' fs']);
            legend('E_1(t)', 'E_2(t-\tau)', 'Location', 'best');
            grid on;

        elseif strcmpi(movie_plot_mode, 'envelope')

            I1_plot = abs(E1).^2;
            I2_plot = abs(E2).^2;

            env_total = I1_plot + I2_plot;
            threshold = 0.03 * max(env_total);
            active_idx = find(env_total > threshold);

            if isempty(active_idx)
                x_left = min(T);
                x_right = max(T);
            else
                x_left = T(active_idx(1));
                x_right = T(active_idx(end));

                padding = 0.15 * (x_right - x_left);
                if padding == 0
                    padding = 20;
                end

                x_left = x_left - padding;
                x_right = x_right + padding;
            end

            x_left = max(x_left, min(T));
            x_right = min(x_right, max(T));

            y_env_max = max([I1_plot(:); I2_plot(:)]);
            if y_env_max == 0
                y_env_max = 1;
            end

            nexttile(1);
            plot(T, I1_plot, 'LineWidth', 1.5);
            hold on;
            plot(T, I2_plot, 'LineWidth', 1.5);
            hold off;
            xlim([x_left x_right]);
            ylim([0 1.15*y_env_max]);
            xlabel('Time (fs)');
            ylabel('Intensity envelope, a.u.');
            title(['Two delayed pulse envelopes, delay = ', num2str(tau, '%.2f'), ' fs']);
            legend('|E_1(t)|^2', '|E_2(t-\tau)|^2', 'Location', 'best');
            grid on;

        else
            error('movie_plot_mode must be field or envelope.');
        end

        % Adaptive autocorrelation window.
        ac_threshold = 0.02 * max(current_ac);
        active_ac_idx = find(current_ac > ac_threshold);

        if isempty(active_ac_idx)
            ac_x_left = min(tau_fs);
            ac_x_right = max(tau_fs);
        else
            ac_x_left = current_tau(active_ac_idx(1));
            ac_x_right = current_tau(active_ac_idx(end));

            ac_padding = 0.20 * (ac_x_right - ac_x_left);
            if ac_padding == 0
                ac_padding = 20;
            end

            ac_x_left = ac_x_left - ac_padding;
            ac_x_right = ac_x_right + ac_padding;
        end

        ac_x_left = max(ac_x_left, min(tau_fs));
        ac_x_right = min(ac_x_right, max(tau_fs));

        ac_y_max = max(current_ac);
        if ac_y_max == 0
            ac_y_max = 1;
        end

        nexttile(2);
        plot(current_tau, current_ac, 'LineWidth', 1.5);
        xlim([ac_x_left ac_x_right]);
        ylim([0 1.15*ac_y_max]);
        xlabel('Delay (fs)');
        ylabel('SHG autocorrelation signal, raw');
        title('Fringe resolved autocorrelation building');
        grid on;

        drawnow;
    end
end

auto_corr_raw = auto_corr;
auto_corr = auto_corr ./ max(auto_corr);


%% ============================================================
%  SECTION 12
%  EXTRACT BACKGROUND FREE INTENSITY AUTOCORRELATION
%
%  ENGINE SECTION
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

delta_tau = mean(diff(tau_fs));
f_delay = linspace(-1/(2*delta_tau), 1/(2*delta_tau), length(tau_fs));

IAC_fft = fftshift(fft(ifftshift(auto_corr))) * delta_tau;
IAC_fft_abs = abs(IAC_fft);

switch lower(intensity_ac_method)

    case 'direct_envelope'

        % --------------------------------------------------------
        % Direct background free intensity autocorrelation:
        %
        % S_IAC(tau) = integral I(t) I(t - tau) dt
        %
        % where I(t) = |U(t)|^2.
        %
        % This is the recommended method for simulation because it does
        % not rely on Fourier filtering of the fringe resolved trace.
        % --------------------------------------------------------

        I_env = abs(U).^2;
        I_env = I_env ./ max(I_env);

        int_ac_bgfree = zeros(size(tau_fs));

        for j = 1:length(tau_fs)

            tau = tau_fs(j);

            I_shifted = interp1(T, I_env, T - tau, 'linear', 0);

            int_ac_bgfree(j) = trapz(T, I_env .* I_shifted);
        end

        if max(int_ac_bgfree) > 0
            int_ac_bgfree = int_ac_bgfree ./ max(int_ac_bgfree);
        end


    case 'fourier_filter'

        % --------------------------------------------------------
        % Fourier filtering method.
        %
        % This tries to extract the low frequency background free
        % intensity autocorrelation from the fringe resolved trace.
        %
        % This can fail for very short few cycle pulses because the
        % carrier components and envelope bandwidth can overlap.
        % --------------------------------------------------------

        center_idx = round(length(f_delay)/2);
        dc_exclusion = round(0.02*length(f_delay));

        % Use known carrier frequency instead of blindly picking the
        % largest FFT peak. This is more stable.
        carrier_frequency_delay = omega0/(2*pi);  % cycles per fs

        % Low pass cutoff below the fundamental optical carrier frequency.
        % This removes omega0 and 2omega0 delay oscillations.
        lowpass_cutoff = 0.45 * carrier_frequency_delay;

        lowpass_mask = abs(f_delay) < lowpass_cutoff;

        IAC_fft_low = IAC_fft .* lowpass_mask;
        int_ac = fftshift(ifft(ifftshift(IAC_fft_low))) / delta_tau;
        int_ac = real(int_ac);

        n_edge = max(5, round(0.03*length(int_ac)));
        bg = mean([int_ac(1:n_edge), int_ac(end-n_edge+1:end)]);

        int_ac_bgfree = int_ac - bg;
        int_ac_bgfree(int_ac_bgfree < 0) = 0;

        if max(int_ac_bgfree) > 0
            int_ac_bgfree = int_ac_bgfree ./ max(int_ac_bgfree);
        end

    otherwise

        error('intensity_ac_method must be direct_envelope or fourier_filter.');
end


% FWHM.
tau_fine = linspace(min(tau_fs), max(tau_fs), 20000);
int_ac_fine = interp1(tau_fs, int_ac_bgfree, tau_fine, 'pchip', 0);

above = find(int_ac_fine >= 0.5);

if isempty(above)
    tau_ac_fwhm = NaN;
else
    tau_ac_fwhm = tau_fine(above(end)) - tau_fine(above(1));
end

fprintf('\n============================================================\n');
fprintf('SHG interferometric autocorrelation simulation complete.\n');
fprintf('Intensity AC method = %s\n', intensity_ac_method);
fprintf('Background free intensity AC FWHM = %.3f fs\n', tau_ac_fwhm);
fprintf('Carrier wavelength used = %.3f nm\n', 2*pi*c_nm_per_fs/omega0);
fprintf('Carrier delay frequency = %.3f 1/fs\n', omega0/(2*pi));
fprintf('============================================================\n\n');

disp('Phase contributions used:');
for k = 1:length(phase_report)
    disp(['  ', phase_report{k}]);
end


%% ============================================================
%  SECTION 13
%  FINAL PLOTS
%
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

lambda_plot = 2*pi*c_nm_per_fs ./ omega;

%% ---------- Basic user friendly plots ----------

if plot_basic_results

    figure('Color','w','Position',[200 200 900 450]);

    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

    nexttile;
    plot(tau_fs, auto_corr, 'LineWidth', 1.2);
    xlabel('Delay (fs)');
    ylabel('Normalized SHG autocorrelation signal');
    title('Fringe resolved autocorrelation');
    xlim([delay_min_fs delay_max_fs]);
    grid on;

    nexttile;
    plot(tau_fs, int_ac_bgfree, 'LineWidth', 1.8);
    xlabel('Delay (fs)');
    ylabel('Normalized Intensity AC');
    title(['Background free intensity AC, FWHM = ', num2str(tau_ac_fwhm, '%.2f'), ' fs']);
    xlim([delay_min_fs delay_max_fs]);
    grid on;

    sgtitle('Fringe Resolved SHG Autocorrelation Simulation Results');

    if save_figures
        saveas(gcf, fullfile(output_folder, 'SHG_autocorrelation_basic_results.png'));
    end
end


%% ---------- Optional diagnostic plots ----------

if plot_diagnostics

    % Avoid unphysical wavelength values when temporal input is used.
    valid_lambda_plot = isfinite(lambda_plot) & lambda_plot > 0 & lambda_plot < 5000;

    lambda_diag = lambda_plot(valid_lambda_plot);
    spectrum_diag = abs(E_omega_initial(valid_lambda_plot)).^2;
    phase_diag = unwrap(angle(E_omega(valid_lambda_plot)));

    figure('Color','w','Position',[100 100 1200 800]);

    tiledlayout(2,3,'Padding','compact','TileSpacing','compact');

    % Input spectrum with adaptive x limits.
    nexttile;
    plot(lambda_diag, spectrum_diag, 'LineWidth', 1.5);
    set(gca, 'XDir','reverse');
    xlabel('Wavelength (nm)');
    ylabel('Spectral intensity, a.u.');
    title('Input spectrum');
    grid on;

    active_spec = spectrum_diag > 0.01*max(spectrum_diag);
    if any(active_spec)
        lambda_active = lambda_diag(active_spec);
        lambda_left = min(lambda_active);
        lambda_right = max(lambda_active);
        lambda_padding = 0.15*(lambda_right - lambda_left);

        if lambda_padding == 0
            lambda_padding = 10;
        end

        xlim([lambda_left-lambda_padding, lambda_right+lambda_padding]);
        set(gca, 'XDir','reverse');
    end

    % Spectral phase with adaptive x limits.
    nexttile;
    plot(lambda_diag, phase_diag, 'LineWidth', 1.5);
    set(gca, 'XDir','reverse');
    xlabel('Wavelength (nm)');
    ylabel('Spectral phase (rad)');
    title('Spectral phase after applied dispersion');
    grid on;

    if any(active_spec)
        xlim([lambda_left-lambda_padding, lambda_right+lambda_padding]);
        set(gca, 'XDir','reverse');
    end

    % Temporal intensity after applied dispersion.
    nexttile;
    plot(T, abs(U).^2, 'LineWidth', 1.5);
    xlabel('Time (fs)');
    ylabel('|E(t)|^2, a.u.');
    title('Temporal intensity after applied dispersion');
    grid on;

    active_time = abs(U).^2 > 0.01*max(abs(U).^2);
    if any(active_time)
        t_active = T(active_time);
        t_left = min(t_active);
        t_right = max(t_active);
        t_padding = 0.2*(t_right - t_left);

        if t_padding == 0
            t_padding = 20;
        end

        xlim([t_left-t_padding, t_right+t_padding]);
    end

    % Fringe resolved autocorrelation.
    nexttile;
    plot(tau_fs, auto_corr, 'LineWidth', 1.2);
    xlabel('Delay (fs)');
    ylabel('Normalized SHG autocorrelation signal');
    title('Fringe resolved autocorrelation');
    xlim([delay_min_fs delay_max_fs]);
    grid on;

    % Background free intensity AC.
    nexttile;
    plot(tau_fs, int_ac_bgfree, 'LineWidth', 1.8);
    xlabel('Delay (fs)');
    ylabel('Normalized intensity AC');
    title(['Background free intensity AC, FWHM = ', num2str(tau_ac_fwhm, '%.2f'), ' fs']);
    xlim([delay_min_fs delay_max_fs]);
    grid on;

    % FFT of fringe resolved autocorrelation trace.
    nexttile;
    normalized_fft = IAC_fft_abs ./ max(IAC_fft_abs);
    plot(f_delay, normalized_fft, 'LineWidth', 1.2);
    xlabel('Frequency in delay domain (1/fs)');
    ylabel('Normalized FFT amplitude');
    title('FFT of fringe resolved autocorrelation trace');
    grid on;

    active_fft = normalized_fft > 0.01;
    if any(active_fft)
        f_active = f_delay(active_fft);
        f_left = min(f_active);
        f_right = max(f_active);
        f_padding = 0.2*(f_right - f_left);

        if f_padding == 0
            f_padding = 0.2;
        end

        xlim([f_left-f_padding, f_right+f_padding]);
    end

    sgtitle('SHG Interferometric Autocorrelation Diagnostic Plots');

    if save_figures
        saveas(gcf, fullfile(output_folder, 'SHG_autocorrelation_diagnostic_plots.png'));
    end
end


%% ---------- Optional separate single trace figures ----------
% These are commented out by default. Uncomment if you want separate
% publication style figures.
%
% figure('Color','w','Position',[200 200 400 550]);
% plot(tau_fs, auto_corr, 'LineWidth', 1.2);
% xlabel('Delay (fs)');
% ylabel('Signal, a.u.');
% title('Fringe resolved autocorrelation');
% xlim([delay_min_fs delay_max_fs]);
% set(gca, 'FontSize', 12, 'LineWidth', 1.5);
% grid on;
%
% if save_figures
%     saveas(gcf, fullfile(output_folder, 'SHG_fringe_resolved_trace.png'));
% end
%
% figure('Color','w','Position',[250 250 400 550]);
% plot(tau_fs, int_ac_bgfree, 'LineWidth', 1.8);
% xlabel('Delay (fs)');
% ylabel('Signal, a.u.');
% title('Background free intensity autocorrelation');
% xlim([delay_min_fs delay_max_fs]);
% set(gca, 'FontSize', 12, 'LineWidth', 1.5);
% grid on;
%
% if save_figures
%     saveas(gcf, fullfile(output_folder, 'SHG_intensity_autocorrelation.png'));
% end


%% ============================================================
%  SECTION 14
%  SAVE RESULTS
%
%  USER DOES NOT NEED TO EDIT THIS SECTION
%% ============================================================

results_table = table(tau_fs(:), auto_corr(:), int_ac_bgfree(:), ...
    'VariableNames', {'Delay_fs','Fringe_Resolved_SHG_AC','Background_Free_Intensity_AC'});

writetable(results_table, fullfile(output_folder, 'SHG_autocorrelation_trace_results.xlsx'));

valid_phase_save = isfinite(lambda_plot) & lambda_plot > 0 & lambda_plot < 5000;

phase_table = table( ...
    omega(valid_phase_save).', ...
    lambda_plot(valid_phase_save).', ...
    abs(E_omega(valid_phase_save)).'.^2, ...
    unwrap(angle(E_omega(valid_phase_save))).', ...
    'VariableNames', {'Omega_rad_per_fs','Wavelength_nm','Spectral_Intensity','Spectral_Phase_rad'});

writetable(phase_table, fullfile(output_folder, 'SHG_autocorrelation_spectral_field_results.xlsx'));

disp('Saved output files in:');
disp(output_folder);


%% ============================================================
%  LOCAL FUNCTIONS
%% ============================================================

function y = zero_if_empty_or_nan(x)

if isempty(x)
    y = 0;
elseif isnan(x)
    y = 0;
else
    y = x;
end

end


function PHI = phase_from_GD_file(file_name, lambda_col, GD_col, omega_grid, omega0, c_nm_per_fs)

data = readmatrix(file_name);

lambda_nm = data(:, lambda_col).';
GD_fs = data(:, GD_col).';

valid = isfinite(lambda_nm) & isfinite(GD_fs);
lambda_nm = lambda_nm(valid);
GD_fs = GD_fs(valid);

omega_data = 2*pi*c_nm_per_fs ./ lambda_nm;

[omega_data, idx] = sort(omega_data);
GD_fs = GD_fs(idx);

[omega_data, idx_unique] = unique(omega_data, 'stable');
GD_fs = GD_fs(idx_unique);

% Dense interpolation before matching grid.
omega_dense = linspace(min(omega_data), max(omega_data), 20000);
GD_dense = interp1(omega_data, GD_fs, omega_dense, 'pchip', 'extrap');

GD_matched = interp1(omega_dense, GD_dense, omega_grid, 'pchip', 'extrap');

% Remove constant GD at omega0 because it only shifts pulse in time.
GD_at_center = interp1(omega_grid, GD_matched, omega0, 'linear', 'extrap');
GD_matched = GD_matched - GD_at_center;

w = omega_grid - omega0;

% Phase is integral of GD over angular frequency.
PHI = cumtrapz(w, GD_matched);

% Remove constant phase at center.
PHI_center = interp1(w, PHI, 0, 'linear', 'extrap');
PHI = PHI - PHI_center;

end


function PHI = phase_from_GDD_file(file_name, lambda_col, GDD_col, omega_grid, omega0, c_nm_per_fs)

data = readmatrix(file_name);

lambda_nm = data(:, lambda_col).';
GDD_fs2 = data(:, GDD_col).';

valid = isfinite(lambda_nm) & isfinite(GDD_fs2);
lambda_nm = lambda_nm(valid);
GDD_fs2 = GDD_fs2(valid);

omega_data = 2*pi*c_nm_per_fs ./ lambda_nm;

[omega_data, idx] = sort(omega_data);
GDD_fs2 = GDD_fs2(idx);

[omega_data, idx_unique] = unique(omega_data, 'stable');
GDD_fs2 = GDD_fs2(idx_unique);

% Dense interpolation before matching grid.
omega_dense = linspace(min(omega_data), max(omega_data), 20000);
GDD_dense = interp1(omega_data, GDD_fs2, omega_dense, 'pchip', 'extrap');

GDD_matched = interp1(omega_dense, GDD_dense, omega_grid, 'pchip', 'extrap');

w = omega_grid - omega0;

% GDD = d^2 phi / d omega^2.
% Integrate once to get GD.
GD_from_GDD = cumtrapz(w, GDD_matched);

% Remove constant GD at center.
GD_center = interp1(w, GD_from_GDD, 0, 'linear', 'extrap');
GD_from_GDD = GD_from_GDD - GD_center;

% Integrate again to get phase.
PHI = cumtrapz(w, GD_from_GDD);

% Remove constant phase at center.
PHI_center = interp1(w, PHI, 0, 'linear', 'extrap');
PHI = PHI - PHI_center;

end