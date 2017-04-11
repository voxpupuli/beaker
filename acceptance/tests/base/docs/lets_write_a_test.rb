# This test ensures that the instructions for the doc:
# `tutorials/lets_write_a_test.md` will execute correctly
test_name 'Cowsay works for the Let\'s Write a Test doc' do
  confine :to, :platform => 'el'
  
  package = 'cowsay'
  step "make sure #{package} is on the host" do
    unless default.check_for_package(package)
      default.install_package(package)
    end
   
    assert(default.check_for_package(package))
  end
  
  step "verify #{package} executes without error codes" do
    result = on(default, "#{package} pants pants pants")
    
    assert(result.exit_code == 0)
  end
end
