## What is This?

Beaker test tagging allows you to add tags to tests (using the [`tag` DSL method](http://www.rubydoc.info/github/puppetlabs/beaker/master/Beaker/DSL/Structure#tag-instance_method)), so that you can include or exclude a specific subset of the tests given for use in this run.  Why would you want to use this?  Here are some examples of what you can do with this functionality:

- Run groups of tests separately from the same testing codebase
- Declare different actions that should be taken when a test fails
- Make new tests go through a provisional process before being considered solid tests

## How Tagging Works

Add tags to a Beaker test at the beginning, like you would if you were using confine.  Things to stay aware of:

- A test that is not executed due to a tag will be considered a ‘skipped’ test
- Tags are free form strings and will not be subjected to any correctness testing
- Tags are NOT case sensitive
- Tagging was added after Beaker 2.14.1.  If you're using that version or older, this isn't available

## Test Examples

Single tag example:

    tag ‘long_running’

Multiple tag example:

    tag ‘long_running’, 'feature_test’

Preferred style block example:

    test_name “my test” do
      tag “filter1”,”filter2”
      …
    end

Preferred style no-block example:

    test_name “my test”
    tag “filter1”,”filter2”

## Command Line Interaction

`--tag`: Run the set of tests matching ALL of the provided single or comma separated list of tags.

`--exclude-tag`: Run the set of tests that do not contain ANY of the provided single or command separated list of tags

To do set intersection combine `--tag` and `--exclude-tag`.

Beaker will raise an error if `--tag` & `--exclude-tag` contain the same tag, however.

## CLI Examples

Execute all ‘long_running’ tests.

    $ beaker --tests path/to/tests --tag long_running

Execute all tests, except those that are ‘feature_test’

    $ beaker --tests path/to/tests --exclude-tag feature_test

Execute all tests that are long_running but not feature_test

    $ beaker --tests path/to/tests --tag long_running --exclude-tag feature_test

Execute all tests marked both 'long_running' and 'feature_test'

    $ beaker --tests /path/to/tests --tags long_running,feature_test

## Environment Variable Support

Equivalent to `--tag`:

    BEAKER_TAG=long_running,feature_test

Equivalent to `--no-tag`:

    BEAKER_EXCLUDE_TAG=long_running,feature_test
