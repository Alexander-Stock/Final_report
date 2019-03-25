function = bulkGamma(DICOM_dir,machineData,gamma_abs,gamma_dta,bixel_width)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fucntion to import a set of dicom images with reference dose distribution and
% caclulate a new dose distribution within matrad for comparison
% call
%   bulkGamma(DICOM_dir, machineData, gamma_abs, gamma_dta,bixel_width)
%
% input
%   DICOM_dir:      Directory of DICOM images. See below for format
%                   infomation
%   machineData:    .MAT file Containt Particle base data for the machine used. All files in
%                   directory must use the same machine data. 
%                   See https://github.com/e0404/matRad/wiki/Particle-Base-Data-File
%                   for more infomation
%   gamma_abs       Absolute gamma criterion
%   gamma_dta       Gamma distance to aggreement criteria
%   bixel_width:    Alows the user to reDefine the bixel width
%                   parameter. Default value is 5.
%
% output
%   No data stored in the workspace on completion of the function. In the
%   same directory as inital DICOM_dir three new folders will be created.
%   The first containsspace for the DICOM CS/CST and reference dose distribution converted
%   to a .MAT object for each image, this must be saved manually becuase of the way the matRad import functions work. 
%   The Second Contains .MAT objects for the distribution caclulated within Matrad for each image, saved automoatically. 
%   The third contains the gammaevaluation between the distributions stored as .MAT objects.
%   All these objects are loadable in MATRAD to view
%   It also contains an additional .MAT object gamma report.
%   Gamma_reportsummarises the results from the gamma analysis across the
%   dataset
%   All produced files will follow the naming convention of the files in
%   DICOM_dir
% 
%   Note: the inital matRad import for each file requires user input for saving the first file and it should be saved with the default suggested name and in the refernce dose directory. Other outputs are saved automatically 
%
% Format of input directory.
% The folder must contatin a list of DICOMS stored in the following heirchy:
% Folder of dicoms> DicomFolder >Patient_Name>Study_Name>Dicom data files 
% Must be ONE study instance only
% Additionaly the dicom Files must include a CS,CST,RTPlan and RTDose
% object.
% 
% Using a non-windows machine may affect order of directories and may
% require adjustments
%
% References/Required files
%   These functions are for interaction with matRad availible at https://github.com/e0404/matRad
%
%   The gamma evaluation takes code from the following source
%   https://github.com/mwgeurts/gamma
%   CalcGamma.m must be on path
%
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear()
%Dummy varibles - uncomment for testing purposes
DICOM_dir = 'testing_master'
machineData = 'generic'
bixel_width = 50
gamma_abs = 5
gamma_dta = 5


%Sets master Directory and creates new folder for outputs 
data_dir = dir('Testing_master');
data_dir = data_dir(~cellfun('isempty', {data_dir.name}));  %removes empty files from array
Master_dir = dir(strcat(data_dir(1).folder,'\Testing_dicom'))
mkdir (data_dir(1).folder,'Reference_Dose')
mkdir (data_dir(1).folder,'New_Dose')
mkdir (data_dir(1).folder,'Gamma_info')

%Initialiss gamma report structure
gamma_report = struct('meta',[],'data' ,struct('File',[],'Agreement',[]))
gamma_report.meta = struct('directory',DICOM_dir,'machine_used' ,machineData,'gamm_Abs' ,gamma_abs, 'gamma_dta' ,gamma_dta)
file_name = strcat(data_dir(1).folder, '\Gamma_info\gamma_report.mat')
save(file_name,'gamma_report')
clear('gamma_report')



%Main Loop - iterates through each dicom master folder and computes the
%following steps:
%1) Import DICOM with refernce dose - user will prompted to save. Use
%defualt name and insure folder 'Reference_Dose' is selected
%2) Import the plan and use the specified machine data to calculate new
%dose and saves in "New_dose"
%3)Performs a gamma analysis with user criteria
%4)Save the result of this into the gamma_report structure
for i = 3:4 %First two entries of dir call are meta infomation, not files
disp(['Loading patient name: ', (Master_dir(i).name)])
    
    %Import dicom info, saves fileList data into new struct
    [ fileList, patientList ] = matRad_scanDicomImportFolder((strcat(Master_dir(i).folder,'\',Master_dir(i).name)));
    files.Filepath =fileList(:,1);
    files.Modality =fileList(:,2);
    files.PatientID =fileList(:,3);
    files.SeriesUID =fileList(:,4);
    files.SeriesNumber =fileList(:,5);
    files.ct = fileList(strcmp(fileList(:,2),'CT'),:);
    files.rtss =fileList(strcmp(fileList(:,2),'RTSTRUCT'),:);
    files.plan =fileList(strcmp(fileList(:,2),'RTPLAN'),:) ;
    files.rtdose =fileList(strcmp(fileList(:,2),'RTDOSE'),:);
    files.resx =str2num(cell2mat(files.ct(1,9)));
    files.resy =str2num(cell2mat(files.ct(1,10)));
    files.resz =str2num(cell2mat(files.ct(1,11)));
    files.Filepath =fileList(:,12);
    files.useDoseGrid = false;
    
    % Try statment to prevent error from intentional misassingment of pln
    try 
        [ct, cst, pln, resultGUI] = matRad_importDicom( files, true )    
    end
    %Load Varibles into workspace
    file_name = strcat(data_dir(1).folder,'\Reference_Dose\',string(files.PatientID(1)),'.mat')
    load(file_name)
    reference.data = resultGUI.physicalDose
    %Import and compute new plan
    
        pln = matRad_importDicomRTPlan(ct,string(files.plan{1}),true)
        pln.propStf.bixelWidth = bixel_width
        pln.machine = machineData
        stf = matRad_generateStf(ct,cst,pln)
        dij = matRad_calcPhotonDose(ct,stf,pln,cst, false)
     try
        resultGUI    = matRad_calcCubes(ones(pln.propStf.numOfBeams,1),dij,cst)
        file_name = strcat(data_dir(1).folder,'\New_dose\',string(files.PatientID(1)),'.mat')
        save(file_name,'resultGUI.physicalDose');
        
    catch
        'Plan import failed'
    end
    
    %Gamma parameters
    reference.start = [-10 -10 -10]; % mm
    reference.width = [0.1 0.1 0.1]; % mm
    target.start = [-10 -10 -10]; % mm
    target.width = [0.1 0.1 0.1]; % mm
    target.data = resultGUI.physicalDose
    %Perform gamma - save result
    gamma = CalcGamma(reference, target, gamma_abs, gamma_dta);
    gamma = double(gamma); % Conversion to double allows veiwing in matrad as a dose object
    file_name = strcat(data_dir(1).folder,'\Gamma_info\',string(files.PatientID(1)),'.mat');
    save(file_name,'gamma')
    %caclulatepassing rate
    rate = sum(gamma < 1,'all')/ numel(gamma)*100;
    
    %Save results to report
    data_to_add.data.File= (Master_dir(i).name);
    data_to_add.data.Agreement= rate
    load(data_dir(1).folder,'\Gamma_info\gamma_report.mat')
    gamma_report.data(end+1)= data_to_add.data
    save(data_dir(1).folder,'\Gamma_info\gamma_report.mat','gamma_report')

%Clear workspace of varibles used to prevent memory
clear('gamma_report','file_name','data_to_add','files')
end


end

