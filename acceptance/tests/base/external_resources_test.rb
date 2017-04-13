test_name 'External Resources Test' do
  step 'Verify EPEL resources are up and available' do
    def epel_url_test(el_version)
      url_base = options[:epel_url]
      url_base = options[:epel_url_archive] if el_version == 5
      url = "#{url_base}/epel-release-latest-#{el_version}.noarch.rpm"
      curl_headers_result = default.exec(Command.new("curl -I #{url}"))
      assert_match(/200 OK/, curl_headers_result.stdout, "EPEL #{el_version} should be reachable at #{url}")
    end

    step 'Verify el_version numbers 5,6,7 are found on the epel resource' do
      [5,6,7].each do |el_version|
        epel_url_test(el_version)
      end
    end

  end
end
