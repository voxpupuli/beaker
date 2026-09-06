module Windows::Group
  include Beaker::CommandFactory

  def group_list
    execute('powershell.exe -NoProfile -NonInteractive -Command "Get-CimInstance Win32_Group -Filter \'LocalAccount=True\' | Select-Object -ExpandProperty Name"') do |result|
      groups = []
      result.stdout.each_line do |line|
        group = line.strip
        next if group.empty?

        groups << group
      end

      yield result if block_given?

      groups
    end
  end

  # using powershell commands as wmic is deprecated/removed on newer Windows
  def group_list_using_powershell
    execute('cmd /c echo "" | powershell.exe "Get-LocalGroup | Select-Object -ExpandProperty Name"') do |result|
      groups = []
      result.stdout.each_line do |line|
        groups << line.strip or next
      end

      yield result if block_given?

      groups
    end
  end

  def group_get(name)
    execute("net localgroup \"#{name}\"") do |result|
      fail_test "failed to get group #{name}" if result.exit_code != 0

      yield result if block_given?
      result
    end
  end

  def group_gid(_name)
    raise NotImplementedError, "Can't retrieve group gid on a Windows host"
  end

  def group_present(name, &)
    execute("net localgroup /add \"#{name}\"", { :acceptable_exit_codes => [0, 2] }, &)
  end

  def group_absent(name, &)
    execute("net localgroup /delete \"#{name}\"", { :acceptable_exit_codes => [0, 2] }, &)
  end
end
