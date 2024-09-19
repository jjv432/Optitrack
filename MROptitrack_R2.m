%% READ ME

%{
    10/31/23 jjv20@fsu.edu

    Use this code to call the optitrack_R2 function.  This function has no
    inputs, and outputs a struct named UserRigidP here.  The purpose of
    this function is to organize your CSV data into conviniently named 
    fields of the struct regardless of the number of markers or rigid 
    bodies.  
    
    These fields include pivot point rotations; pivot point x, y, and z; 
    and marker x, y, and z.  MME refers to Mean Marker Error- you likely 
    won't need this.

    The optitrack_R2 function will ask for a number of inputs.  These will
    include file name, total number of markers, and number of rigid bodies.

    The file must be a csv and the inputted name can not include the .csv
    extension.

    The total number of markers must be an integer and is the sum of IR
    markers placed on all rigid bodies.

    The number of rigid bodies will be however many rigid bodies you
    exported into the CSV

    If you are seeing unexpected data, ensure your export rotation type was
    'XYZ' and not quaternion.  You can know if you accidentally used
    quaternion by checking the values of your data.  If one of them is just
    an array of all ones, you messed up.  Also, the CSV will have a column
    names 'W'.

    
%}

%% Code Implementation

%{

    When calling your data, the format will always be:
    UserRigidP.[RIGIDBODYNAME][(X/Y/Z)/(ROTATIONX/Y/Z)].  For example, for
    a rigid body named 'Foam', plottings its x vs z would look like:

            plot(UserRigidP.FoamX, UserRigidP.FoamZ)
%}
clc
close all
format compact

%Call this before trying to plot to familiarize yourself with field names
UserRigidP = optitrack_R2(); 


