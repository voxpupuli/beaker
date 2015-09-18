require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #curl_with_retries" do

  step "#curl_with_retries CURRENTLY fails with a RuntimeError if retries are exhausted without fetching the specified URL" do
    # NOTE: would expect that this would raise Beaker::Host::CommandFailure

    assert_raises RuntimeError do
      curl_with_retries \
        "description",
        default,
        "file:///non/existent.html",
        desired_exit_codes = [0],
        max_retries = 2,
        retry_interval = 0.01
    end
  end

  step "#curl_with_retries retrieves the contents of a URL after retrying" do
    # TODO: testing curl_with_retries relies on having a portable means of
    # making an unavailable URL available after a period of time.
  end

  step "#curl_with_retries can retrieve the contents of a URL after retrying, when given a hosts array" do
    # TODO: testing curl_with_retries relies on having a portable means of
    # making an unavailable URL available after a period of time.
  end
end
