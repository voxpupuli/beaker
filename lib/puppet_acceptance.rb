module PuppetAcceptance

  Dir[File.expand_path(File.join(File.dirname(__FILE__), 'puppet_acceptance', '*.rb'))].each do |file|
    require file
  end
  include PuppetCommands
  include CommandFactory

end
