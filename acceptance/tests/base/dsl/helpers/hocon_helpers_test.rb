require 'hocon/config_value_factory'

test_name 'Hocon Helpers Test' do

  hocon_filename = 'hocon.conf'
  step 'setup : create hocon file to play with' do
    hocon_content = <<-END
      {
        setting1 : "value1",
        setting2 : 2,
        setting3 : False
      }
    END
    create_remote_file(hosts, hocon_filename, hocon_content)
  end

  step '#hocon_file_read : reads doc' do
    doc = hocon_file_read_on(hosts[0], hocon_filename)
    assert(doc.has_value?('setting2'))
  end

  step '#hocon_file_edit_on : set_value and verify it exists' do
    hocon_file_edit_on(hosts, hocon_filename) do |_host, doc|
      doc2 = doc.set_value('c', '[4, 5]')

      assert(doc2.has_value?('c'), 'Should have inserted "c" value!')
    end
  end

  step '#hocon_file_edit_on : testing failure modes' do
    def test_filename_failure(filename)
      begin
        hocon_file_edit_on(hosts, filename) do |_, _|
          fail('block should not run in failure mode')
        end
        fail('execution should not continue in failure mode')
      rescue ArgumentError => e
        assert(e.to_s.include?('requires a filename'))
      else
        fail('No exception raised in failure mode')
      end
    end

    step 'filename is nil' do
      test_filename_failure(nil)
    end

    step 'filename is empty string' do
      test_filename_failure('')
    end

    step 'no block given' do
      begin
        hocon_file_edit_on(hosts, hocon_filename)
        fail('execution should not continue in failure mode')
      rescue ArgumentError => e
        assert(e.to_s.include?('No block was provided'))
      else
        fail('No exception raised in failure mode')
      end
    end
  end

  step '#hocon_file_edit_on : verify saving workflow' do
    step '#hocon_file_edit_on : set_value and save' do
      hocon_file_edit_on(hosts, hocon_filename) do |host, doc|
        doc2 = doc.set_value('a.b', '[1, 2, 3, 4, 5]')
        create_remote_file(host, hocon_filename, doc2.render)
      end
    end

    step '#hocon_file_edit_on : independently read value to verify save' do
      hocon_file_edit_on(hosts, hocon_filename) do |_host, doc|
        msg_fail = 'Should have saved "a.b" value inserted in previous step'
        assert(doc.has_value?('a.b'), msg_fail)
      end
    end
  end

  step '#hocon_file_edit_in_place_on : verify auto-saving workflow' do
    step '#hocon_file_edit_in_place_on : set_value and save' do
      hocon_file_edit_in_place_on(hosts, hocon_filename) do |_host, doc|
        doc.set_value('c.d', '[6, 2, 73, 4, 45]')
      end
    end

    step '#hocon_file_edit_in_place_on : verify save' do
      hocon_file_edit_on(hosts, hocon_filename) do |_host, doc|
        msg_fail = 'Should have saved "c.d" value inserted in previous step'
        assert(doc.has_value?('c.d'), msg_fail)
      end
    end
  end
end