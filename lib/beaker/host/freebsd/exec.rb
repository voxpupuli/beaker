module FreeBSD::Exec
  include Beaker::CommandFactory

  def echo_to_file(str, filename)
    # FreeBSD gets weird about special characters, we have to go a little OTT here
    escaped_str = str.gsub(/\t/,'\\t').gsub(/\n/,'\\n')

    exec(Beaker::Command.new("printf \"#{escaped_str}\" > #{filename}"))
  end
end
