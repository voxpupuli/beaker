desc "Buid distributable files"
task :dist do
  system <<-HERE
  cd dist
  rm ptest.tgz puppet.tgz
  tar czf ptest.tgz ptest/bin/* 
  tar czf puppet.tgz puppet/*
  cd ..
  echo "Completed building ptest.tgz and puppet.tgz"
  HERE
end
