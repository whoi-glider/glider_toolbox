function [meta, data] = loadSlocumData(ascii_dir, name_pattern_nav, name_pattern_sci, varargin)
%LOADSLOCUMDATA  Load Slocum data from dba files in directory.
%
%  Syntax:
%    [META, DATA] = LOADSLOCUMDATA(ASCII_DIR, NAME_PATTERN_NAV, NAME_PATTERN_SCI)
%    [META, DATA] = LOADSLOCUMDATA(ASCII_DIR, NAME_PATTERN_NAV, NAME_PATTERN_SCI, OPTIONS)
%    [META, DATA] = LOADSLOCUMDATA(ASCII_DIR, NAME_PATTERN_NAV, NAME_PATTERN_SCI, OPT1, VAL1, ...)
%
%  [META, DATA] = LOADSLOCUMDATA(ASCII_DIR, NAME_PATTERN_NAV, NAME_PATTERN_SCI)
%  loads data and from Slocum files in ascii text format (dba) contained in 
%  directory named by string ASCII_DIR and whose name matches regular expression
%  in string NAME_PATTERN_NAV (navigation files) or in string NAME_PATTERN_SCI 
%  (science files). META and DATA contain loaded metadata and data in the format 
%  returned by functions DBACAT and DBAMERGE.
%
%  [META, DATA] = LOADSLOCUMDATA(ASCII_DIR, NAME_PATTERN_NAV, NAME_PATTERN_SCI, OPTIONS) and
%  [META, DATA] = LOADSLOCUMDATA(ASCII_DIR, NAME_PATTERN_NAV, NAME_PATTERN_SCI, OPT1, VAL1, ...) 
%  accept the following options, given in key-value pairs OPT1, VAL1... or in a
%  struct OPTIONS with field names as option keys and field values as option 
%  values, allowing to restrict the time range or the sensor set of the data to
%  load, or to specify the output format:
%    FORMAT: data output format.
%      String setting the format of the output DATA. Valid values are:
%        'array': DATA is a matrix with sensor readings as columns 
%           ordered as in the 'sensors' metadata field.
%        'struct': DATA is a struct with sensor names as field names and column 
%           vectors of sensor readings as field values.
%      Default value: 'array'
%    TIMENAV: navigation data time stamp.
%      String setting the navigation data time sensor for merging and sorting 
%      sensor cycles.
%      Default value: 'm_present_time'
%    TIMESCI: scientific data time stamp.
%      String setting the scientific data time sensor for merging and sorting 
%      sensor cycles.
%      Default value: 'sci_m_present_time'
%    SENSORS: sensor filtering list.
%      String cell array with the names of the sensors of interest. If given,
%      only sensors present in both the input data sets and this list will be 
%      present in output. The string 'all' may also be given, in which case 
%      sensor filtering is not performed and all sensors in input list will be 
%      present in output.
%      Default value: 'all' (do not perform sensor filtering).
%    PERIOD: time filtering boundaries.
%      Two element numeric array with the start and the end of the time interval 
%      of interest (seconds since 1970-01-01 00:00:00.00 UTC). If given, only 
%      sensor cycles with timestamps within this period will be present in
%      output. The string 'all' may also be given, in which case time filtering 
%      is not performed and all sensors cycles in input data sets will be 
%      present in output.
%      Default value: 'all' (do not perform time filtering).
%
%  Notes:
%    This function is a simple shortcut to load all dba data in a directory
%    belonging to the same deployment or transect. It just filters the contents
%    of the directory and calls DBA2MAT, DBACAT and DBAMERGE, bypassing the
%    given options (with conversions when needed).
%
%  Examples:
%    [meta, data] = ...
%      loadSlocumData(ascii_dir, name_pattern_nav, name_pattern_sci)
%    [meta, data] = ...
%      loadSlocumData(ascii_dir, name_pattern_nav, name_pattern_sci, ...
%                     'timenav', 'm_present_time', 'timesci', 'sci_m_present_time', ...
%                     'sensors', sensors_of_interest, 'period', period_of_interset, ...
%                     'format', 'struct');
%
%  See also:
%    DIR
%    REGEXP
%    DBA2MAT
%    DBACAT
%    DBAMERGE
%
%  Author: Joan Pau Beltran
%  Email: joanpau.beltran@socib.cat

%  Copyright (C) 2013-2014
%  ICTS SOCIB - Servei d'observacio i prediccio costaner de les Illes Balears.
%
%  This program is free software: you can redistribute it and/or modify
%  it under the terms of the GNU General Public License as published by
%  the Free Software Foundation, either version 3 of the License, or
%  (at your option) any later version.
%
%  This program is distributed in the hope that it will be useful,
%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%  GNU General Public License for more details.
%
%  You should have received a copy of the GNU General Public License
%  along with this program.  If not, see <http://www.gnu.org/licenses/>.

  error(nargchk(3, 13, nargin, 'struct'));
  
  
  %% Set options and default values.
  options.format = 'array';
  options.timenav = 'm_present_time';
  options.timesci = 'sci_m_present_time';
  options.sensors = 'all';
  options.period = 'all';
  
  
  %% Parse optional arguments.
  % Get option key-value pairs in any accepted call signature.
  argopts = varargin;
  if isscalar(argopts) && isstruct(argopts{1})
    % Options passed as a single option struct argument:
    % field names are option keys and field values are option values.
    opt_key_list = fieldnames(argopts{1});
    opt_val_list = struct2cell(argopts{1});
  elseif mod(numel(argopts), 2) == 0
    % Options passed as key-value argument pairs.
    opt_key_list = argopts(1:2:end);
    opt_val_list = argopts(2:2:end);
  else
    error('glider_toolbox:loadSlocumData:InvalidOptions', ...
          'Invalid optional arguments (neither key-value pairs nor struct).');
  end
  % Overwrite default options with values given in extra arguments.
  for opt_idx = 1:numel(opt_key_list)
    opt = lower(opt_key_list{opt_idx});
    val = opt_val_list{opt_idx};
    if isfield(options, opt)
      options.(opt) = val;
    else
      error('glider_toolbox:loadSlocumData:InvalidOption', ...
            'Invalid option: %s.', opt);
    end
  end
  
  
  %% Get file names matching the desired patterns.
  % Flatten lists to discard unmatched files.
  ascii_dir_contents = dir(ascii_dir);
  dba_nav_sel = ~[ascii_dir_contents.isdir] ...
    & ~cellfun(@isempty, regexp({ascii_dir_contents.name}, name_pattern_nav));
  dba_sci_sel = ~[ascii_dir_contents.isdir] ...
    & ~cellfun(@isempty, regexp({ascii_dir_contents.name}, name_pattern_sci));
  dba_nav_names = {ascii_dir_contents(dba_nav_sel).name};
  dba_nav_sizes = [ascii_dir_contents(dba_nav_sel).bytes];
  dba_sci_names = {ascii_dir_contents(dba_sci_sel).name};
  dba_sci_sizes = [ascii_dir_contents(dba_sci_sel).bytes];
  disp(['Navigation data files found: ' num2str(numel(dba_nav_names)) ...
        ' (' num2str(sum(dba_nav_sizes)*2^-10) ' kB).']);
  disp(['Scientific data files found: ' num2str(numel(dba_sci_names)) ...
        ' (' num2str(sum(dba_sci_sizes)*2^-10) ' kB).']);
  
  
  %% Load navigation files.
  disp('Loading navigation files...');
  dba_nav_files = cell(size(dba_nav_names));
  dba_nav_success = false(size(dba_nav_names));
  meta_nav = cell(size(dba_nav_names));
  data_nav = cell(size(dba_nav_names));
  for dba_nav_idx = 1:numel(dba_nav_names)
    try
     dba_nav_files{dba_nav_idx} = ...
       fullfile(ascii_dir, dba_nav_names{dba_nav_idx});
     [meta_nav{dba_nav_idx}, data_nav{dba_nav_idx}] = ...
       dba2mat(dba_nav_files{dba_nav_idx}, 'sensors', options.sensors);
     dba_nav_success(dba_nav_idx) = true;
    catch exception
      disp(['Error loading ascii file ' dba_nav_files{dba_nav_idx} ':']);
      disp(getReport(exception, 'extended'));
    end
  end
  meta_nav = meta_nav(dba_nav_success);
  data_nav = data_nav(dba_nav_success);
  disp(['Navigation files loaded: ' ...
        num2str(numel(data_nav)) ' of ' num2str(numel(dba_nav_names)) '.']);


  %% Load science files.
  disp('Loading science files...');
  dba_sci_files = cell(size(dba_sci_names));
  dba_sci_success = false(size(dba_sci_names));
  meta_sci = cell(size(dba_sci_names));
  data_sci = cell(size(dba_sci_names));
  for dba_sci_idx = 1:numel(dba_sci_names)
    try
     dba_sci_files{dba_sci_idx} = ...
       fullfile(ascii_dir, dba_sci_names{dba_sci_idx});
     [meta_sci{dba_sci_idx}, data_sci{dba_sci_idx}] = ...
       dba2mat(dba_sci_files{dba_sci_idx}, 'sensors', options.sensors);
     dba_sci_success(dba_sci_idx) = true;
    catch exception
      disp(['Error loading ascii file ' dba_sci_files{dba_sci_idx} ':']);
      disp(getReport(exception, 'extended'));
    end
  end
  meta_sci = meta_sci(dba_sci_success);
  data_sci = data_sci(dba_sci_success);
  disp(['Science files loaded: ' ...
        num2str(numel(data_sci)) ' of ' num2str(numel(dba_sci_names)) '.']);


  %% Combine data from each bay.
  [meta_nav, data_nav] = dbacat(meta_nav, data_nav, options.timenav);
  [meta_sci, data_sci] = dbacat(meta_sci, data_sci, options.timesci);
  
  
  %% Merge data from both bays.
  [meta, data] = ...
    dbamerge(meta_nav, data_nav, meta_sci, data_sci, ...
             'sensors', options.sensors, 'period', options.period, ...
             'format', options.format);

end
