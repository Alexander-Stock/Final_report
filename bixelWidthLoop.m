clear()
load 'Orig.mat'
iter = 10;
stf_time = zeros(iter,1);
stf_mem = zeros(iter,1);
dij_mem = zeros(iter,1);
dij_time = zeros(iter,1);
start_mem = zeros(iter,1)
bixel_width_arr = zeros(iter,1)
FluenceCalctime =zeros(iter,1);
gui_mem = zeros(iter,1)
totalBixels = zeros(iter,1)
Data = struct('stf_time',stf_time,'stf_mem',stf_mem,'dij_mem',dij_mem,'bixel_width_arr',bixel_width_arr,'FluenceCalctime',FluenceCalctime,'gui_mem',gui_mem)
for i = 1:iter
    try
        clear(dij,resultGui,stf,pln) %Deletes prev results
    end
    load 'DefaultPlan.mat'
    a= whos(); %lists all varibles
    %start_mem(i)=sum([a(:).bytes])
    %Varible Para
    pln.propStf.bixelWidth      = 2*i;
    bixel_width_arr(i) = pln.propStf.bixelWidth 
    pln.propStf.gantryAngles    = [0]; 
    pln.propStf.couchAngles     = [0]; 
    %stf
    tic
    stf = matRad_generateStf(ct,cst,pln);
    stf_time(i) = toc;
    a= whos('stf'); %lists all varibles
    stf_mem(i)=a.bytes
    %dij
    tic
    dij = matRad_calcPhotonDose(ct,stf,pln,cst);
    dij_time(i) = toc;
    a= whos('dij'); %lists all varibles
    dij_mem(i)=a.bytes;
    %Result
    tic
    resultGUI = matRad_fluenceOptimization(dij,cst,pln);
    FluenceCalctime(i) = toc;
    a= whos('resultGUI');
    gui_mem(i) = a.bytes;
    a= whos(); %lists all varibles
    total_memory(i)=sum([a(:).bytes])
    
   
    total_time(i) =stf_time(i) + dij_time(i) + FluenceCalctime(i)
end
Data = struct('stf_time',stf_time,'stf_mem',stf_mem,'dij_mem',dij_mem,'bixel_width_arr',bixel_width_arr,'FluenceCalctime',FluenceCalctime,'gui_mem',gui_mem)
