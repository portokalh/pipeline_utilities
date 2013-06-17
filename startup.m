
old_paths={
  '/pipe_home/script/matlab_functions_local'
  '/pipe_home/matlab_functions_external/NIFTI_20110921'
  '/pipe_home/matlab_library/NIFTI_20110921'
  '/pipe_home/script/matlab_functions_local/T2WsuseptibilityReg/'
  '/recon_home/script/dir_radish/modules/matlab/agilent'
  '/recon_home/script/dir_radish/modules/matlab'
  '/recon_home/script/dir_radish/modules/matlab/mat_recon_pipe/agilent'
  '/recon_home/script/dir_radish/modules/matlab/mat_recon_pipe/aspect'
  '/recon_home/script/dir_radish/modules/matlab/civm_matlab_common_utils/'
  '/recon_home/script/dir_radish/modules/matlab/mat_recon_pipe'
  '/recon_home/script/dir_radish/modules/matlab/mr_relaxation_calc/'
  '/recon_home/script/dir_radish/modules/matlab/radish_filter'
};
old_genpaths={
  '/recon_home/script/dir_radish/modules/matlab/mathworks'
};
workstation_home=getenv('workstation_home');
paths={
  [ workstation_home '/recon/mat_recon_pipe']
  [ workstation_home '/shared/civm_matlab_common_utils' ]
};
gen_paths={
  [ workstation_home 'shared/mathworks']
};

for p=1:length(paths)
    if exist(old_paths{p},'dir')
	addpath(old_paths{p});
    end
    if exist(paths{p},'dir')
	addpath(paths{p});
    end
end

for p=1:length(genpaths)
    if exist(old_genpaths{p},'dir')
	addpath(old_genpath(paths{p}));
    end
    if exist(genpaths{p},'dir')
	addpath(genpath(paths{p}));
    end
end
