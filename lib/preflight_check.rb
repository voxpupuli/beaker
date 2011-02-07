# Place to add small pre-test tasks
#

# What version of Puppet are we installing?
def puppet_version
  version=""

  unless File.file? "#{$work_dir}/tarballs/LATEST"
    puts " Can not find: #{$work_dir}/tarballs/LATEST"
  end

  begin
    File.open("#{$work_dir}/tarballs/LATEST") do |file|
      while line = file.gets
        if /(\w.*)/ =~ line then
          version=$1
          puts "Found: Puppet Version #{version}"
        end
      end
    end
  rescue
    version = 'unknown'
  end
  return version
end
