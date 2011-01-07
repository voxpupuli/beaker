# Place to add small pre-test tasks
#

# What version of Puppet are we installing?
def puppet_version
  version=""
  parent_dir=""
  parent_dir=$1 if /^(\/\w.*)(\/\w.+)/ =~ $work_dir

  File.open("#{parent_dir}/installer/VERSION") do |file|
    while line = file.gets
      if /(\w.*)/ =~ line then
        version=$1
        puts "Found: Puppet Version #{version}"
      end
    end
  end
  return version
end
