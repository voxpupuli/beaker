module Windows::Pkg
  include PuppetAcceptance::CommandFactory

  def check_for_package name
    result = exec(PuppetAcceptance::Command.new("which #{name}"), :acceptable_exit_codes => (0...127))
    result.exit_code == 0 
  end

  def install_package name
    if not check_for_package('setup.exe')
      execute("curl --retry 5 http://cygwin.com/setup-x86.exe -o /cygdrive/c/Windows/System32/setup.exe")
    end
    execute("setup.exe -q -n -N -d -R c:\\\\cygwin -s http://cygwin.osuosl.org -P #{name}") 
  end

end
