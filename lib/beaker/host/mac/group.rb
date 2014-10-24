module Mac::Group
  include Beaker::CommandFactory

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

  def group_gid(name)
    gid = -1
    execute("dscacheutil -q group -a name #{name}") do |result|
      result.stdout.each_line { |line|
        if line =~ /^gid:/
          gid = line[5, line.length - 5]
          break
        end
      }
      gid
    end
  end

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

  def group_absent(name, &block)
    execute("if dscl . -list /Groups/#{name}; then dscl . -delete /Groups/#{name}; fi", {}, &block)
  end

  private

  def gid_next
    gid_last = execute("dscl . -list /Groups PrimaryGroupID | sort -k 2 -g | tail -1 | awk '{print $2}'")
    gid_last.to_i + 1
  end
end
