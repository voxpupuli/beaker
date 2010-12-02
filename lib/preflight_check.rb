# Put pre test tasks 
#
def preflight_check

    $version=""
    parent_dir=""
    parent_dir=$1 if /^(\/\w.*)(\/\w.+)/ =~ $work_dir

    File.open("#{parent_dir}/installer/VERSION") do |file|
      while line = file.gets
        if /(\w.*)/ =~ line then
          $version=$1
          puts "Puppet Enterprise Version #{$version}"
        end
      end
    end
end
