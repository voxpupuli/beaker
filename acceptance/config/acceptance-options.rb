{
  :load_path => File.join('acceptance', 'lib'),
  :ssh => {
    :keys => ["id_rsa_acceptance", "#{ENV.fetch('HOME', nil)}/.ssh/id_rsa-acceptance"],
  },
}
