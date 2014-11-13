module Mac::User
  include Beaker::CommandFactory

  # Gets a list of user names on the system
  #
  # @param [Proc] block Additional actions or insertions
  #
  # @return [Array<String>] The list of user names on the system
  def user_list(&block)
    execute('dscacheutil -q user') do |result|
      users = []
      result.stdout.each_line do |line|
        users << line.split(': ')[1].strip if line =~ /^name:/
      end

      yield result if block_given?

      users
    end
  end

  # Gets the user information in /etc/passwd format
  #
  # @param [String] name Name of the user
  # @param [Proc] block Additional actions or insertions
  #
  # @yield [String] The actual mac dscacheutil output
  # @return [String] User information in /etc/passwd format
  # @raise [FailTest] Raises an Assertion failure if it can't find the name
  #                   queried for in the returned block
  def user_get(name, &block)
    answer = ""
    execute("dscacheutil -q user -a name #{name}") do |result|
      fail_test "failed to get user #{name}" unless result.stdout =~  /^name: #{name}/
      ui = Hash.new  # user info
      result.stdout.each_line { |line|
        pieces = line.split(': ')
        ui[pieces[0].to_sym] = pieces[1].strip if pieces[1] != nil
      }
      answer  = "#{ui[:name]}:#{ui[:password]}:#{ui[:uid]}:#{ui[:gid]}:"
      answer << "#{ui[:name]}:#{ui[:dir]}:#{ui[:shell]}"

      yield result if block_given?
    end
    answer
  end

  # Makes sure the user is present, creating them if necessary
  #
  # @param [String] name Name of the user
  # @param [Proc] block Additional actions or insertions
  def user_present(name, &block)
    user_exists = false
    execute("dscacheutil -q user -a name #{name}") do |result|
       user_exists = result.stdout =~  /^name: #{name}/
    end

    return if user_exists

    uid = uid_next
    gid = gid_next
    create_cmd  =     "dscl . create /Users/#{name}"
    create_cmd << " && dscl . create /Users/#{name} NFSHomeDirectory /Users/#{name}"
    create_cmd << " && dscl . create /Users/#{name} UserShell /bin/bash"
    create_cmd << " && dscl . create /Users/#{name} UniqueID #{uid}"
    create_cmd << " && dscl . create /Users/#{name} PrimaryGroupID #{gid}"
    execute(create_cmd)
  end

  # Makes sure the user is absent, deleting them if necessary
  #
  # @param [String] name Name of the user
  # @param [Proc] block Additional actions or insertions
  def user_absent(name, &block)
    execute("if dscl . -list /Users/#{name}; then dscl . -delete /Users/#{name}; fi", {}, &block)
  end

  # Gives the next uid not used on the system
  #
  # @return [Fixnum] The next uid not used on the system
  def uid_next
    uid_last = execute("dscl . -list /Users UniqueID | sort -k 2 -g | tail -1 | awk '{print $2}'")
    uid_last.to_i + 1
  end

  # Gives the next gid not used on the system
  #
  # @return [Fixnum] The next gid not used on the system
  def gid_next
    gid_last = execute("dscl . -list /Users PrimaryGroupID | sort -k 2 -g | tail -1 | awk '{print $2}'")
    gid_last.to_i + 1
  end
end
