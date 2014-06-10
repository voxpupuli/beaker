require 'beaker/tasks/rake_task'

Beaker::Tasks::RakeTask.new do |t,args|
  t.type  = args[:type]
  t.hosts = args[:hosts]
end

desc "Run Beaker PE tests"
Beaker::Tasks::RakeTask.new("beaker:test:pe",:hosts) do |t,args|
  t.type = 'pe'
  t.hosts = args[:hosts]
end

desc "Run Beaker Git tests"
Beaker::Tasks::RakeTask.new("beaker:test:git",:hosts) do |t,args|
  t.type = 'git'
  t.hosts = args[:hosts]
end