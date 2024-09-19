function [UserRigidP] = optitrack_R2()

%% Dev Notes
%{
    REV2, 11/14/23 
    jjv20@fsu.edu
    
    REVISIONS:
    
    Fixed issue in previous revision that could not assign more than one 
    rigid body's data at a time.

    Has been tested and works with: three rigid bodies with three markers;
    one rigid body with four markers; and one rigid body with four markers
    and two rigid bodies with three markers.
    
    Added some error checking to marker quality

    Added save and normalize 'features'.
%}

%% Setup


%These are the types of rotation that can be associated with a pivot point
RotationNames = ["RotationX", "RotationY", "RotationZ"]; 

%Markers are assigned X, Y, Z, or MQ (Marker Quality) in the .csv
MarkerNames = ["X", "Y", "Z", "MQ"];

%% General User Input (SKIP)

%Calling user's .csv.  Must be in same folder
FileNamePlain = input("Enter the filename (without extension): ", "s");
FileName = strcat(FileNamePlain, '.csv');

%Information about the experiment
MarkerCount = input("Enter the total number of markers used (int): "); %TOTAL Number of markers used in the test
RigidBodyCount = input("Enter the number of rigid bodies created (int): "); %Number of rigid bodies


%ColRange sets the bounds of the data.  This avoids reading 'unlabeled' markers
%from the CSV.

ColRange = 2 + 7*RigidBodyCount + 4*MarkerCount + 3*MarkerCount; 

%2 for time and index, then 7 for the pivot point data (RotX, RotY, RotZ, X, Y, Z, MME), 
% then 4 for raw data (X, Y, Z, MQ), then 3 for interpolated data (X, Y, Z)


%% Retrieving Rigid Body Names

%Reading the data as a string so the names of rigid bodies can be checked

RigidNames = readmatrix(FileName, 'OutputType', 'string', 'Delimiter', ','); 


%RowHelp is a variable that shifts the row that rigid body names are read
%from in RigidNames.  This is a seemingly random formatting change.
RowHelp = 0;

%Checking for this 'random' error
if RigidNames(1) == "Format Version"
    RowHelp = 1;
end

%RigidNames will be used to assign data for the pivot point.  Notice the
%order of the names in the first half of the data are the order the bodies
%were exported, whereas the interpolated data is alphabatized.

%Reducing to name row only (Skips first two (or three) rows)
RigidNames = RigidNames(2+RowHelp, :); 

fileID = fopen(FileName, 'r');
for a = 1:(4+RowHelp) %Had to change from 2 before?
    RigidNames = fgetl(fileID);
end
RigidNames = string(strsplit(RigidNames, ','));
fclose(fileID);
%Removing repeats, this leaves only the rigid body names in the CSV.
%Must use 'stable' to avoid alphabatizing


%Removing formatting from RigidNames so they work as struct fields
%Also removing "Unlabeled" markers (noise/interference)
for i=1:numel(RigidNames)
    RigidNames(i) = erase(RigidNames(i), ":"); %Avoid problems with struct naming convention (Can't contain : in a field)
    RigidNames(i) = erase(RigidNames(i), "..."); %Avoid problems with struct naming convention (Can't contain ... in a field)
    RigidNames(i) = erase(RigidNames(i), "'"); %Avoid problems with struct naming convention (Can't contain ... in a field)
    RigidNames(i) = erase(RigidNames(i), '"'); %Avoid problems with struct naming convention (Can't contain ... in a field)
    if (contains(RigidNames(i), "Unlabeled") || contains(RigidNames(i), "Name"))
        RigidNames(i) = "Zero";
    end
end


LengthTemp = 0;

RigidNames(find(RigidNames == "")) = [];


%Removing Zeros created above
RigidNames(RigidNames=="Zero") = []; %Removing and resizing unlabed (interference) data points
RigidNames = rmmissing(RigidNames); %Removing 'missing' from array 

RigidNames = unique(RigidNames, 'stable');

%RigidNames now only contains the names of the rigid bodies in the user's
%csv.

%% Marker and Time Data

%Only reading marker data what is within ColRange
TakeData = readmatrix(FileName, 'Range', 'A8'); 
TakeData = TakeData(:,1:ColRange); 

%Time (in seconds)
Time = TakeData(:,2);
UserRigidP.Time = Time; %Adding Time to the struct


%% Pivot Point Data (X, Y, Z, ROTX, ROTY, ROTZ, MQ)

%{
    'Section' refers to how many unique names are associated with the rigid 
     body. Each will have one for the rigid body, and then one for each 
     marker on the body.  So, a body with 4 markers with have 5 sections.
%}


%Number of Section Per Body that have occured so far (used in the for loop
%below)
totalSPB = 0;
temp = [];
SpecificName = zeros(1, RigidBodyCount);


% Normalizing data.  This will shift every field (addition or subtraction)
% such that index 1 is equal to 0.  All fields will be normalized
% independently, therefore you should not try to plot multiple markers or
% bodies together if you've normalized
normalizeBool = 0;
NormalizeTemp = input("Do you want to normalize each field of your data? (Y/N): ", "s");

if (NormalizeTemp == 'Y')||(NormalizeTemp == 'y')
    normalizeBool = 1;
    fprintf('\n***Normalizing***\n\n')
else
    fprintf('\n***Not normalizing***\n\n')
end

fprintf("From left to right in the CSV:...\n")

for z = 1:RigidBodyCount
    
    %Temporary name being used to name struct field
    SpecificName = input(['Enter the name of the number ' num2str(z) ' rigid body: '], 's');
    Names(z) = string(SpecificName);
    

    %Calculating current Section Per Body, and assigning it to a new array
    %called SectionPerBody to be used later
    SectionPerBody(z) = sum(contains(RigidNames, SpecificName));


    %Centroid Rotation and Position Values 
    for a = 1:7
        if(a<4)
            %First three values in the section are rotation
            temp = strcat(RigidNames{1+totalSPB}, RotationNames{a}); 
        else
            %Other four values are position and MME. Kept general in case
            %transition to quaternion desired
            w = a-numel(RotationNames); 
            temp = strcat(RigidNames{1+totalSPB}, MarkerNames{w}); 
        end
        tempColumn = 2+a+7*(z-1) + (totalSPB)*3; %Where seven is bc 3Rot + 3Pos + MME = 7 
        x = 0;
        if normalizeBool
            x = TakeData(1, tempColumn);
        end
        UserRigidP.(temp) = TakeData(:,tempColumn) - x;
        
        if(a==7 && (mean(TakeData(:,tempColumn)))>10^-3)
            fprintf("\n*******************************************\nWarning: Poor Marker Quality in Rigid Body: %s\nDesired: 10^-4\nCurrent: %d\nMarkers May Be Too Small or Too Close to Each Other\n*******************************************\n\n", RigidNames{1+totalSPB}, mean(TakeData(:,tempColumn)))
        end
        clear tempColumn
    end
    %Keeping track of how many SPB have passed
    totalSPB = totalSPB + SectionPerBody(z);
    
end



%% Interpolated Marker Data

%Column which 'corrected' marker data begins
%2 for time, 7 for each pivot point's data, then 4 for each marker.
%totalSPB-RigidBodyCount = number of markers per body

colShift = 2 + 7*RigidBodyCount + 4*(totalSPB-RigidBodyCount)

%This will keep SectionPerBody associated with the same rigid body name
%even after alphabatizing with regards to rigid body name.  This will make
%it so that any number of sections can be had for each rigid body and the
%variable a (below) will have the correct value after each loop
temp = [Names; string(SectionPerBody)];
[temps, order] = sort(temp(1,:));
alphaSPB = temp(:,order);
alphaSPB = alphaSPB (2,:); %alphabetic Sections Per Body


clear temps

%Interpolated values are alphabetical in the CSV
alphaRigidNames = sort(RigidNames); %Alphabatizing to match output file

%Need this so that SectionPerBody values are now in 'alphabetical' order
%too.

a = 0; %Counts previous SPB
y = colShift; %y is the start column for the current rigid body
for n = 1 : RigidBodyCount %Each rigid body
    for h = 1:(str2double(alphaSPB(n))-1) %Each marker
        for m = 1:3 %x, y, z for each marker
           
            %Creating name for struct field name
            temp = strcat(alphaRigidNames{1+h+a}, MarkerNames{m});

            %X is the column of data to read
            x = y + m

            if normalizeBool
                z = TakeData(1, x);
            else 
                z = 0;
            end

            %Assign this column of data to the appropriately named field 
            UserRigidP.(temp) = TakeData(:,x)-z;

        
        end
        y = y + 3; %three columns (X, Y, Z) have passed

    end

    a = a + str2num(alphaSPB(n)); %alphaSPB(n) sections have now passed
    
end
%% Optional Save Data to File

% This will allow the user to save the struct to a .mat file.  This will
% overwrite any previous saves, and will take the same name as the CSV
% filename.  This will remove the need to run the program multiple times
% for the same data
SaveBool = input("Do you want to save this data to a .mat file named after the CSV (overwrites previous saves)? (Y/N): ", 's');

if (SaveBool == 'Y')||(SaveBool == 'y')
    save(strcat(FileNamePlain,".mat"),"-struct","UserRigidP");
    fprintf("\n***Saved to .mat file***\n")
else
    fprintf("\n***Data not saved to .mat file***\n")
end





%% Cleanup 

fprintf('\nDone! \n\n')

%Values that will only clutter workspace


clear i m MarkerCount n previousColumn previousSectionPerBody RigidBodyCount ...
SectionPerBody SpecificName startIndex z temp a ColRange colShift k RowHelp...
SPBSoFar tempColumn w x totalSPB MarkerNames RotationNames



end