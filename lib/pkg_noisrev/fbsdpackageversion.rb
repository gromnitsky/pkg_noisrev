require 'dl/import'

module Pkg_noisrev
  module FbsdPackageVersion
    extend DL::Importer
    
    DLL_PATH = File.dirname(__FILE__) + '/dll'
    DLL_NAME = 'version.so.1'
  
    dlload(DLL_PATH + '/' + DLL_NAME)
    extern 'int version_cmp(const char *, const char *)'
  end
end
