module Mac::Group
  include Beaker::CommandFactory

  # Gets a list of group names on the system
  #
  # @param [Proc] block Additional actions or insertions
  #
  # @return [Array<String>] The list of group names on the system
  def group_list(&block)
    execute('dscacheutil -q group') do |result|
      groups = []
      result.stdout.each_line do |line|
        groups << line.split(': ')[1].strip if line =~ /^name:/
      end

      yield result if block_given?

      groups
    end
  end

  # Gets the group information in /etc/group format
  #
  # @param [String] name Name of the group you want
  # @param [Proc] block Additional actions or insertions
  #
  # @yield [String] The actual mac dscacheutil output
  # @return [String] Group information in /etc/group format
  # @raise [FailTest] Raises an Assertion failure if it can't find the name
  #                   queried for in the returned block
  def group_get(name, &block)
    execute("dscacheutil -q group -a name #{name}") do |result|
      fail_test "failed to get group #{name}" unless result.stdout =~ /^name: #{name}/
      gi = Hash.new  # group info
      result.stdout.each_line { |line|
        pieces = line.split(': ')
        gi[pieces[0].to_sym] = pieces[1].strip if pieces[1] != nil
      }
      answer = "#{gi[:name]}:#{gi[:password]}:#{gi[:gid]}"

      yield answer if block_given?
    end
  end

  # Gets the gid of the given group
  #
  # @param [String] name Name of the group
  #
  # @return [String] gid of the group
  def group_gid(name)
    gid = -1
    execute("dscacheutil -q group -a name #{name}") do |result|
      result.stdout.each_line { |line|
        if line =~ /^gid:/
          gid = (line[5, line.length - 5]).chomp
          break
        end
      }
      gid
    end
  end

  # Makes sure the group is present, creating it if necessary
  #
  # @param [String] name Name of the group
  # @param [Proc] block Additional actions or insertions
  def group_present(name, &block)
    group_exists = false
    execute("dscacheutil -q user -a name #{name}") do |result|
      group_exists = result.stdout =~  /^name: #{name}/
    end

    return if group_exists

    gid = gid_next
    create_cmd  =     "dscl . create /Groups/#{name}"
    create_cmd << " && dscl . create /Groups/#{name} PrimaryGroupID #{gid}"
    execute(create_cmd)
  end

  # Makes sure the group is absent, deleting it if necessary
  #
  # @param [String] name Name of the group
  # @param [Proc] block Additional actions or insertions
  def group_absent(name, &block)
    execute("if dscl . -list /Groups/#{name}; then dscl . -delete /Groups/#{name}; fi", {}, &block)
  end

  # Gives the next gid not used on the system
  #
  # @return [Fixnum] The next gid not used on the system
  def gid_next
    gid_last = execute("dscl . -list /Groups PrimaryGroupID | sort -k 2 -g | tail -1 | awk '{print $2}'")
    gid_last.to_i + 1
  end
end
