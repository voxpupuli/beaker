{
  :load_path => File.join('acceptance', 'lib'),
  :ssh => {
    :keys => ["#{ENV['HOME']}/.ssh/id_rsa-acceptance"],
  },
}
