module Aix::File
  include Beaker::CommandFactory

  def tmpfile(name = '', extension = nil)
    execute("rndnum=${RANDOM} && touch /tmp/#{name}.${rndnum}#{extension} && echo /tmp/#{name}.${rndnum}#{extension}")
  end

  def tmpdir(name = '')
    execute("rndnum=${RANDOM} && mkdir /tmp/#{name}.${rndnum} && echo /tmp/#{name}.${rndnum}")
  end

  def path_split(paths)
    paths.split(':')
  end
end
