module Windows::Pkg
  include PuppetAcceptance::CommandFactory

  def check_for_package name
    result = exec(PuppetAcceptance::Command.new("which #{name}"), :acceptable_exit_codes => (0...127))
    result.exit_code == 0 
  end

  def install_package name
    cygwin = ""
    rootdir = ""
    result = exec(PuppetAcceptance::Command.new("wmic os get osarchitecture | grep 32"), :acceptable_exit_codes => (0...127))
    if result.exit_code == 0 #32 bit version
      rootdir = "c:\\\\cygwin"
      cygwin = "setup-x86.exe"
    else  #64 bit version
      rootdir = "c:\\\\cygwin64"
      cygwin = "setup-x86_64.exe"
    end
    if not check_for_package(cygwin)
      execute("curl --retry 5 http://cygwin.com/#{cygwin} -o /cygdrive/c/Windows/System32/#{cygwin}")
    end
    execute("#{cygwin} -q -n -N -d -R #{rootdir} -s http://cygwin.osuosl.org -P #{name}") 
  end

end
