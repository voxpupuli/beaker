test_name "verify we can print the function reference"
run_puppet_on(agents, :doc, "-r", "type") do
    fail_test "didn't print type reference" unless
        stdout.include? 'Type Reference'
end
