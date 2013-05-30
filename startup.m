
paths={
  '/pipe_home/script/matlab_functions_local'
  '/pipe_home/matlab_functions_external/NIFTI_20110921'
  '/pipe_home/matlab_library/NIFTI_20110921'
  '/pipe_home/script/matlab_functions_local/T2WsuseptibilityReg/'
  '/recon_home/script/dir_radish/modules/matlab'
  '/recon_home/script/dir_radish/modules/matlab/agilent'
  '/recon_home/script/dir_radish/modules/matlab/civm_matlab_common_utils/'
  '/recon_home/script/dir_radish/modules/matlab/mat_recon_pipe'
  '/recon_home/script/dir_radish/modules/matlab/mr_relaxation_calc/'
  '/recon_home/script/dir_radish/modules/matlab/radish_filter'
};
genpaths={
  '/recon_home/script/dir_radish/modules/matlab/mathworks'
};

for p=1:length(paths)
    if exist(paths{p},'dir')
	addpath(paths{p});
    end
end

for p=1:length(genpaths)
    if exist(genpaths{p},'dir')
	addpath(genpath(paths{p}));
    end
end
