
display=false;
old_paths={
    '/pipe_home/script/matlab_functions_local'
    '/pipe_home/script/matlab_functions_local/T2WsuseptibilityReg/'
    '/pipe_home/script/matlab_functions_local/image_filters'
    '/pipe_home/script/matlab_functions_local/skull_stripping'
    '/pipe_home/script/matlab_functions_local/label_measurements'
    '/pipe_home/matlab_library/NIFTI_20130326'
    '/pipe_home/matlab_library/NIFTI_20110921'
    '/pipe_home/matlab_functions_external/NIFTI_20110921'
    %  '/recon_home/script/dir_radish/modules/matlab/agilent'
    %  '/recon_home/script/dir_radish/modules/matlab'
    '/recon_home/script/dir_radish/modules/matlab/mat_recon_pipe'
    '/recon_home/script/dir_radish/modules/matlab/mat_recon_pipe/aspect'
    '/recon_home/script/dir_radish/modules/matlab/mat_recon_pipe/agilent/radish'
    '/recon_home/script/dir_radish/modules/matlab/mat_recon_pipe/agilent/radish/radish_filter'
    '/recon_home/script/dir_radish/modules/matlab/civm_matlab_common_utils/'
    
    '/recon_home/script/dir_radish/modules/matlab/mr_relaxation_calc/'
    
    };
old_genpaths={
    '/recon_home/script/dir_radish/modules/matlab/mathworks'
    
    };
workstation_home=getenv('WORKSTATION_HOME');
if isempty(workstation_home)
    p = mfilename('fullpath');
    p = fileparts(p);
    
end
paths={
    [ workstation_home '/recon/mat_recon_pipe' ]
    [ workstation_home '/recon/mat_recon_pipe/aspect' ]
    [ workstation_home '/recon/mat_recon_pipe/agilent/radish' ]
    [ workstation_home '/recon/mat_recon_pipe/agilent/radish/radish_filter' ]
    [ workstation_home '/shared/civm_matlab_common_utils/' ]
    [ workstation_home '/analysis/mr_relaxation_calc/' ]
    [ workstation_home '/analysis/label_measurements/' ]
    
    };
genpaths={
    [ workstation_home '/shared/mathworks']
    [ workstation_home '/shared/matlab_img_processing']
    };

for p=1:length(old_paths)
    if exist(old_paths{p},'dir')
        addpath(old_paths{p});
    else
        if display
            fprintf('Path not found:%s\n',old_paths{p});
        end
    end
end
for p=1:length(paths)
    if exist(paths{p},'dir')
        addpath(paths{p});
    else
        if display
            fprintf('Path not found:%s\n',paths{p});
        end
    end
end

for p=1:length(old_genpaths)
    if exist(old_genpaths{p},'dir')
        addpath(genpath(old_genpaths{p}));
    else
        if display
            fprintf('Path not found:%s\n',old_genpaths{p});
        end
    end
end
for p=1:length(genpaths)
    if exist(genpaths{p},'dir')
        addpath(genpath(genpaths{p}));
    else
        if display
            fprintf('Path not found:%s\n',genpaths{p});
        end
    end
end
if display
    fprintf('Removing .svn paths\n');
end
patharray=strsplit(path,':');
for p=length(patharray):-1:1
    if regexpi(patharray{p},'.*\.svn')
        %         fprintf('\t%s\n',patharray{i});
        rmpath(patharray{p});
    end
end

clear workstation_home paths genpaths old_paths old_genpaths  patharray p display 