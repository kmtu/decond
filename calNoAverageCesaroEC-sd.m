#!/home/kmtu/bin/octave -qf

clear all
format long

global kB beta basicCharge ps nm volume timestep t numIonTypes;
kB = 1.3806488E-23; #(J K-1)
beta = 1.0/(kB*300); #(J-1)
basicCharge = 1.60217646E-19; #(Coulomb)
ps = 1.0E-12; #(s)
nm = 1.0E-9; #(m)

if (nargin() < 3)
    error("Usage: $calNoAverageCesaroEC-sd.m <filename.sdCorr> <maxLag -1=max (step)> <systemVolume(nm^3)> [deltaStep] \n\
where <filename> is used for both input and output: filename.sd and filename.xvg,\n\
optional deltaStep is for integrating the sdCorr every deltaStep, default is 1.");
else
    filename = argv(){1};
    maxLag = str2num(argv(){2});
    volume = str2num(argv(){3}) * (1.0E-9)**3; #(m3)
    extnamePos = rindex(filename, "."); #locate the position of the extension name
    baseFilename = filename(1:extnamePos-1);
    if (nargin() > 3)
        deltaStep = round(str2num(argv(){4}))
        if (deltaStep <= 0)
            deltaStep = 1;
        endif
    else
        deltaStep = 1
    endif
endif

#.sdCorr file contains timestep, charge(), numAtoms(), timeLags(), rBins(), and sdCorr()
load(filename);

numIonTypes = length(charge);
numIonTypePairs = numIonTypes**2;

# modifying data according to deltaStep if it is greater than 1
if (deltaStep > 1)
    timestep *= deltaStep;
    timeLags = timeLags(1:deltaStep:end);
    for i = [1:numIonTypePairs]
        sdCorr(:,:,i) = sdCorr(:,:,i)(1:deltaStep:end, :);
    endfor
    if (maxLag > 0)
        maxLag = floor(maxLag / deltaStep);
    endif
endif

if (maxLag < 0)
    maxLag = length(timeLags) - 1;
endif

#for showing
timestep
maxLag 

t = [0:maxLag];

%function ec = integrateEC(corrData, maxLag)
%    global kB beta basicCharge ps nm volume timestep t;
%    if (length(corrData) == 1 && maxLag > 0)
%        #there is only one ion so no mutual-corr{i}{i}
%        ec = 0;
%    else
%        ec = beta * basicCharge**2 / volume * trapz(t(1:maxLag+1)', corrData(1:maxLag+1)) * timestep * nm**2 / ps;
%    endif
%endfunction

function index = zipIndexPair(idx1, idx2)
    global numIonTypes;
    index = (idx1 - 1) * numIonTypes + idx2;
endfunction

%for T = [0:maxLag]
%    ecTotal(T+1) = 0;
%    for i = [1:numIonTypes]
%        ecAutocorr(T+1, i) = charge(i) * charge(i) * integrateEC(vAutocorr{i}, T);
%#        ecAutocorrNoAverageCesaro(T, i) = sum(ecAutocorr(1:T, i));
%        if (T > 0)
%            ecAutocorrNoAverageCesaro(T, i) = trapz([0:T]', ecAutocorr(1:T+1, i)) * timestep;
%        endif
%        ecTotal(T+1) = ecTotal(T+1) + ecAutocorr(T+1, i);
%        for j = [1:numIonTypes]
%            ecCorr(T+1,zipIndexPair(i,j)) = charge(i) * charge(j) * integrateEC(vCorr{i,j}, T);
%#            ecCorrNoAverageCesaro(T, zipIndexPair(i,j)) = sum(ecCorr(1:T, zipIndexPair(i,j)));
%            if (T > 0)
%                ecCorrNoAverageCesaro(T, zipIndexPair(i,j)) = trapz([0:T]', ecCorr(1:T+1, zipIndexPair(i,j))) * timestep;
%            endif
%            ecTotal(T+1) = ecTotal(T+1) + ecCorr(T+1, zipIndexPair(i,j));
%        endfor
%    endfor
%#    ecTotalNoAverageCesaro(T) = sum(ecTotal(1:T));
%    if (T > 0)
%        ecTotalNoAverageCesaro(T) = trapz([0:T], ecTotal(1:T+1)) * timestep;
%    endif
%endfor
%ecTotalNoAverageCesaro = ecTotalNoAverageCesaro';

function [type1, type2] = unzipIonTypePairs(pairIndex)
    global numIonTypes;
    type1 = floor((pairIndex-1) / numIonTypes) + 1;
    type2 = mod(pairIndex-1, numIonTypes) + 1;
endfunction

function ec = cumIntegrateEC(sdCorrData, maxLag)
    global kB beta basicCharge ps nm volume timestep t;
    if (length(sdCorrData) == 1 && maxLag > 0)
        #there is only one ion so no mutual-sdcorr
        ec = 0;
    else
        ec = beta * basicCharge**2 / volume * cumtrapz(t(1:maxLag+1)', sdCorrData(1:maxLag+1)) * timestep * nm**2 / ps;
    endif
endfunction

ecSDTotal = zeros(maxLag+1, length(rBins)); 
for i = [1:numIonTypePairs]
    for j = [1:length(rBins)]
        [ionType1, ionType2] = unzipIonTypePairs(i);
        ecSDCorr(:, j, i) = charge(ionType1) * charge(ionType2) * cumIntegrateEC(sdCorr(:,j,i), maxLag);
        ecSDCorrNoAverageCesaro(:, j, i) = cumtrapz(ecSDCorr(:, j, i)) * timestep;
    endfor
    ecSDTotal .+= ecSDCorr(:, :, i);
endfor
for j = [1:length(rBins)]
    ecSDTotalNoAverageCesaro(:, j) = cumtrapz(ecSDTotal(:, j)) * timestep;
endfor

timeLags = [0:maxLag]' * timestep;
save(strcat(baseFilename, ".ecSDNoAverageCesaro-dt-", num2str(deltaStep)), "numIonTypes", "timestep", "timeLags", "ecSDTotalNoAverageCesaro", "ecSDCorrNoAverageCesaro");
