test_name 'External Resources Test' do
  step 'Verify EPEL is correct' do
    def epel_url_test(el_version, arch, pkg_key)
      url = "#{@options[:epel_url]}/#{el_version}/#{arch}/#{@options[pkg_key]}"
      curl_headers_result = default.exec(Command.new("curl -I #{url}"))
      assert_match(/200 OK/, curl_headers_result.stdout, "EPEL #{el_version} should be reachable")
    end

    step 'arch is i386' do
      @arch = 'i386'
      # epel-7 does not provide packages for i386
      step 'EPEL 6' do
        epel_url_test(6, @arch, :epel_6_pkg)
      end
      step 'EPEL 5' do
        epel_url_test(5, @arch, :epel_5_pkg)
      end
    end

    step 'arch is x86_64' do
      @arch = 'x86_64'
      step 'EPEL 7' do
        # note: interpolation gets around URL change for epel 7
        epel_url_test(7, "#{@arch}/e", :epel_7_pkg)
      end
      step 'EPEL 6' do
        epel_url_test(6, @arch, :epel_6_pkg)
      end
      step 'EPEL 5' do
        epel_url_test(5, @arch, :epel_5_pkg)
      end
    end
  end
end