module Mac::Exec
  include Beaker::CommandFactory

  def touch(file, abs=true)
    (abs ? '/usr/bin/touch' : 'touch') + " #{file}"
  end

end
