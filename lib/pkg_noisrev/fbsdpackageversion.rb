require 'dl/import'

module Pkg_noisrev
  module FbsdPackageVersion
    extend DL::Importer
    
    DLL_PATH = [File.dirname(__FILE__),
                File.absolute_path("#{File.dirname(__FILE__)}/../../ext")]
    DLL_NAME = 'version.so'

    begin
      dlload(DLL_PATH[0] + '/' + DLL_NAME)
    rescue
      dlload(DLL_PATH[1] + '/' + DLL_NAME)
    end
    extern 'int version_cmp(const char *, const char *)'
  end
end
