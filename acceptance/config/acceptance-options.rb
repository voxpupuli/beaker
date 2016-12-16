{
  :load_path => File.join('acceptance', 'lib'),
  :ssh => {
    :keys => ["id_rsa_acceptance", "#{ENV['HOME']}/.ssh/id_rsa-acceptance"],
  },
}
