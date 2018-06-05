## What is This?

Beaker test tagging allows you to add tags to tests (using the [`tag` DSL method](http://www.rubydoc.info/github/puppetlabs/beaker/master/Beaker/DSL/TestTagging#tag-instance_method)), so that you can include or exclude a specific subset of the tests given for use in this run.  Why would you want to use this?  Here are some examples of what you can do with this functionality:

- Run groups of tests separately from the same testing codebase
- Declare different actions that should be taken when a test fails
- Make new tests go through a provisional process before being considered solid tests

## How Tagging Works
 Add tags to a Beaker test at the beginning, like you would if you were using confine.  Things to stay aware of:

- A test that is not executed due to a tag will be considered a ‘skipped’ test
- Tags are free form strings and will not be subjected to any correctness testing
- Tags are NOT case sensitive
- Tagging was added after Beaker 2.14.1.  If you're using that version or older, this isn't available
- `--test-tag-or` was added after Beaker 3.12.0. If you're using an older version, this isnt available

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

`--test-tag-and`: Run the set of tests matching ALL of the provided single or comma-separated list of tags.

`--test-tag-or`: Run the set of tests matching ANY of the provided single or comma-separated list of tags.

`--test-tag-exclude`: Run the set of tests that do not contain ANY of the provided single or comma-separated list of tags.

Beaker will raise an error if `--test-tag-and` & `--test-tag-exclude` contain the same tag, however.

Beaker will also raise an error if you use both `--test-tag-or` & `--test-tag-and`, because it won't be able to determine which order they should be used in.

## CLI Examples

Execute all ‘long_running’ tests.

    $ beaker --tests path/to/tests --test-tag-and long_running

Execute all tests, except those that are ‘feature_test’

    $ beaker --tests path/to/tests --test-tag-exclude feature_test

Execute all tests that are long_running but not feature_test

    $ beaker --tests path/to/tests --test-tag-and long_running --test-tag-exclude feature_test

Execute all tests marked both 'long_running' and 'feature_test'

    $ beaker --tests /path/to/tests --test-tag-and long_running,feature_test

## Environment Variable Support

Equivalent to `--test-tag-and`:

    BEAKER_TEST_TAG_AND=long_running,feature_test

Equivalent to `--test-tag-or`:

    BEAKER_TEST_TAG_OR=long_running,feature_test

Equivalent to `--test-tag-exclude`:

    BEAKER_TEST_TAG_EXCLUDE=long_running,feature_test
