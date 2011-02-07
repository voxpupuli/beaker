desc "Buid distributable files"
task :dist do
  system <<-HERE
  cd dist
  rm ptest.tgz puppet.tgz
  tar czf ptest.tgz ptest/bin/* 
  tar czf puppet.tgz puppet/*
  cd ..
  echo "Completed building ptest.tgz and puppet.tgz"
  cd tarballs/
  rm answers.tar
  tar cf answers.tar q_*
  cd ..
  echo "Completed building answers.tar"
  HERE
end
