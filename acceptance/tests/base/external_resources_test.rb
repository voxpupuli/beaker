test_name 'External Resources Test' do
  step 'Verify EPEL resources are up and available' do
    def build_url(el_version)
      url_base = options[:epel_url]
      "#{url_base}/epel-release-latest-#{el_version}.noarch.rpm"
    end

    def epel_url_test(el_version)
      url = build_url(el_version)
      # -I option just asks for headers, not looking to download the package
      curl_cmd = Command.new("curl -I #{url}")
      host = default
      curl_headers_result = Result.new(host, curl_cmd)
      curl_fail_msg = "EPEL curl failed, waiting for fibonacci backoff to retry..."

      repeat_fibonacci_style_for(10) do
        curl_headers_result = host.exec(curl_cmd)
        curl_succeeded = curl_headers_result.exit_code == 0
        logger.info(curl_fail_msg) unless curl_succeeded
        curl_succeeded
      end
      assert_match(/200 OK/, curl_headers_result.stdout, "EPEL #{el_version} should be reachable at #{url}")
    end

    step 'Verify el_version numbers 6,7,8 are found on the epel resource' do
      [6,7,8].each do |el_version|
        epel_url_test(el_version)
      end
    end
  end
end
