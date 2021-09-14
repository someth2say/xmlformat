Gem::Specification.new do |s|
    ### REQUIRED ###
      s.name         = 'xmlformat'
      s.version      = '0.1.0'
      s.summary      = "XML formatting tool"
      s.authors      = ["Jordi Sola"]
    # s.files        = ["bin/xmlformat.rb","bin/xmlformat.conf"]
    # s.executables << 'xmlformat.rb'
      s.files         = `git ls-files`.split("\n")
      s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
      s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
    # s.require_paths = ["lib"]
    ### WARNING ###
      s.license      = 'GPL3'
      s.homepage     = 'https://github.com/someth2say/xmlformat'
    ### RECOMMENDED ###
      s.description  = "Formats XML files"
      s.email        = 'jordisola@redhat.com'
    ###
    end
