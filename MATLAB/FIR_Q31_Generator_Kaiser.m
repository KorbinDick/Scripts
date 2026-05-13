% Testing for making FIR Lowpass Filter (Q31) for right now

% Complete:
% Adjustable fs (sampling rate)
% Adjustable fc (cutoff/corner frequency)
% Adjustable Tap/Coefficent count
% Adjustable filename
% Adjustable bandpass or lowpass or highpass or stop
% Adjustable window, kaiser, chebyshev, hamming, hann, rectangular

clear

% Setting up dialog box
dlgtitle = 'FIR Q31 Filter File Generation Kaiser Window';

prompt = {'Filename:'...
    'Sampling Rate(Hz):'...
    'Type of Filter: (low / high / bandpass / stop)'...
    'Transition Band(s)(Hz): (Ex. LPF -> 1000 1300, Ex. BPF -> 1000 1300 2000 2200)'...
    'Passband Ripple(s) and Stopband Attenuation(s)(dB): (Ex. LPF -> 0.5 60, Ex. BPF -> 60 0.5 60)'}; 


definput = {'FIR_Q31_8kHz_LPF','48000', 'bandpass', '1000 1300 2000 2200', '40 0.5 40'};
fieldsize = [1 100; 1 100; 1 100; 1 100; 1 100];
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);



% Input error handling
if isempty(answer)
    error("CLOSED PROGRAM");
end

if length(strsplit(answer{2})) ~= 1
    error("INVALID SAMPLING RATE");
end

if length(strsplit(answer{3})) ~= 1
    error("INVALID FILTER TYPE");
end

if isscalar(strsplit(answer{4}))
    error("SPECIFIED ONLY ONE FREQUENCY, MUST BE RANGE FOR TRANSITION BAND");
end


% Initial error checking pass, parse input data
filename = append(answer{1}, ".h");
fs = str2double(answer{2});
filterType = lower(answer{3});
fcuts = str2double(strsplit(answer{4}));
attenuations = strsplit(answer{5});

devs = zeros;
numBands = length(fcuts) - 1;

switch filterType
    case 'low'
        mags = [1 0];
        devs(1) = (10^((str2double(attenuations(1)))/20)) - 1;
        devs(2) = 10^((-1*str2double(attenuations(2)))/20);
    case 'high'
        mags = [0 1];
        devs(1) = 10^((-1*str2double(attenuations(1)))/20);
        devs(2) = (10^((str2double(attenuations(2)))/20)) - 1;

    case 'bandpass'
        mags = mod(0:numBands-1, 2);
        for k = 1:length(attenuations)
            if mod(k, 2)
            devs(k) = 10^((-1*str2double(attenuations(k)))/20);
            else
            devs(k) = (10^((str2double(attenuations(k)))/20)) - 1;
            end
        end
    case 'stop'
        mags = mod(1:numBands, 2);
        for k = 1:length(attenuations)
            if mod(k, 2)
            devs(k) = (10^((str2double(attenuations(k)))/20)) - 1;
            else
            devs(k) = 10^((-1*str2double(attenuations(k)))/20);
            end
        end
    otherwise
        error("INVALID FILTER TYPE");
end


[n,Wn,beta,ftype] = kaiserord(fcuts,mags,devs,fs);
b = fir1(n,Wn,ftype,kaiser(n+1,beta),"noscale");

[H, f] = freqz(b,1,4096,fs);
plot(f,20*log10(abs(H)))
grid on
xlabel('Frequency (Hz)')
ylabel('Magnitude (dB)')
title(answer{1})
xlim([0 20000])
ylim([-120 10])

% Scaling to Q31, fir1 outputs row vector double-precision 
% floating point normalized on [-1.0, 1.0]
q31_mult = 2^31-1;
q31 = int64(round(b*q31_mult));


% Creating header file
fileID = fopen(filename,'w');

fprintf(fileID,"#define NUM_TAPS %d\n\n", length(b));

fprintf(fileID,"static const int32_t filterTaps[NUM_TAPS] = {\n");

for i = 1:length(b)
    
    if i < length(b)
        fprintf(fileID,"    %d,\n", q31(i));
    else
        fprintf(fileID,"    %d\n", q31(i));
    end
    
end

fprintf(fileID,"};");

fclose(fileID);