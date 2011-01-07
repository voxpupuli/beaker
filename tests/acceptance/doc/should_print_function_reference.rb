test_name "verify we can print the function reference"
run_puppet_on(agents, :doc, "-r", "function") do
    fail_test "didn't print function reference" unless
        stdout.include? 'Function Reference'
end
