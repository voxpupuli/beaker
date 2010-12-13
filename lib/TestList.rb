# Build list of tests
# Accecpt test dir as arg
# Require all the tests and return list of test names

def test_list(path)
  if File.basename(path) =~ /^\W/
    [] # skip .hiddens and such
  elsif File.directory?(path) then
    puts "Looking for tests in #{path}"
    Dir.entries(path).
      collect { |entry| test_list(File.join(path,entry)) }.
      flatten.
      compact
  elsif path =~ /\.rb$/
    puts "Found #{path}"
    require path
    [path[/\S+\/(\S+)$/,1]]
  end
end

