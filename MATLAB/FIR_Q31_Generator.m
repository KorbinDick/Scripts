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
dlgtitle = 'FIR Filter Q31 File Generation';

prompt = {'Filename:'...
    'Sampling Rate (kHz):'...
    'Type of Filter (low / high / bandpass / stop):'...
    'Cutoff Frequency (kHz) (BPF / stop 3kHz - 12kHz example -> 3 12):'...
    'Filter Order:'...
    'Window Type (kaiser, cheb, hamming, hann, rect):'...
    'Window Parameter (beta for kaiser, rs for cheb):'};

definput = {'FIR_Q31_48kHz_BPF_1.5_3_127','48', 'bandpass', '.2 .9', '4095', 'kaiser', '5.65'};
fieldsize = [1 80; 1 80; 1 80; 1 80; 1 80; 1 80; 1 80];
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);



% Input error handling
if isempty(answer)
    error("CLOSED PROGRAM");
end

if length(strsplit(answer{2})) ~= 1
    error("SPECIFIED MORE THAN ONE SAMPLING RATE");
end

if length(strsplit(answer{3})) ~= 1
    error("SPECIFIED MORE THAN ONE FILTER TYPE");
end

if length(strsplit(answer{5})) ~= 1
    error("SPECIFIED MORE THAN ONE FILTER ORDER");
end

if length(strsplit(answer{6})) ~= 1
    error("SPECIFIED MORE THAN ONE WINDOW TYPE");
end

if length(strsplit(answer{7})) ~= 1
    error("SPECIFIED MORE THAN ONE WINDOW PARAMETER");
end


% Initial error checking pass, parse input data
filename = append(answer{1}, ".h");
fs = str2double(answer{2}) * 1000;
filterType = lower(answer{3});
fcSplit = str2double(strsplit(answer{4}));
filterOrder = str2double(answer{5});
windowType = lower(answer{6});
winParam = str2double(answer{7});


% Checking user input for corner frequency
if (length(fcSplit) ~= 1) && (filterType == "high" || filterType == "low")
    error("HIGHPASS/LOWPASS USED WITH TWO CORNER FREQUENCIES; " + ...
        "CHECK FILTER PARAMETERS");
end

if (isscalar(fcSplit)) && (filterType == "bandpass" || filterType == "stop")
    error("BANDPASS/STOP USED WITH ONE CORNER FREQUENCY; " + ...
        "CHECK FILTER PARAMETERS");
end


% Adjusting window length in the case of odd high/stop filter order
if mod(filterOrder,2) ~= 0 && (filterType == "high" || filterType == "stop")
    % If odd number order for high/stop, make order even to keep window
    % parameter the same
    filterOrder = filterOrder+1;
end

% Window length for fir1 is n+1 (filterOrder+1)
windowLength = filterOrder+1;



% Create normalizd frequency or range of frequencies used for fir1
if isscalar(fcSplit)
    fc = fcSplit(1) * 1000;
    Wn = fc / (fs/2);

else
    Wn = (fcSplit .* 1000) / (fs/2);
end

% Deciding which window type to use, winParam isn't used if not kaiser or
% cheb
switch windowType
    case 'kaiser'
        win = kaiser(windowLength, winParam);
    case 'cheb'
        win = chebwin(windowLength, winParam);
    case 'hamming'
        win = hamming(windowLength);
    case 'hann'
        win = hann(windowLength);
    case 'rect'
        win = rectwin(windowLength);
    otherwise
        warning('UNKNOWN WINDOW, DEFAULTING TO HAMMING');
        win = hamming(windowLength);
end


b = fir1(filterOrder, Wn, filterType, win);



% Plotting on Figure 1
[H, f] = freqz(b,1,4096,fs);
plot(f,20*log10(abs(H))),
grid on
xlabel('Frequency (Hz)')
ylabel('Magnitude (dB)')
title(answer{1})
xlim([0 20000])
ylim([-120 20])


% Scaling to Q31, fir1 outputs row vector double-precision 
% floating point normalized on [-1.0, 1.0]
q31_mult = 2^31;
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