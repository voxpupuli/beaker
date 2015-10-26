# encoding: UTF-8
require 'spec_helper'

module Beaker
  describe Logger do
    let(:my_io)     { MockIO.new                         }
    let(:logger)    { Logger.new(my_io, :quiet => true)  }
    let(:test_dir)  { 'tmp/tests' }
    let(:dummy_prefix)  { 'dummy' }

    context '#convert' do
      let(:valid_utf8)  { "/etc/puppet/modules\n├── jimmy-appleseed (\e[0;36mv1.1.0\e[0m)\n├── jimmy-crakorn (\e[0;36mv0.4.0\e[0m)\n└── jimmy-thelock (\e[0;36mv1.0.0\e[0m)\n" }
      let(:invalid_utf8) {"/etc/puppet/modules\n├── jimmy-appleseed (\e[0;36mv1.1.0\e[0m)\n├── jimmy-crakorn (\e[0;36mv0.4.0\e[0m)\n└── jimmy-thelock (\e[0;36mv1.0.0\e[0m)\xAD\n"}

      it 'preserves valid utf-8 strings' do
        expect( logger.convert(valid_utf8) ).to be === valid_utf8
      end
      it 'strips out invalid utf-8 characters' do
        #this is 1.9 behavior only
        if RUBY_VERSION.to_f >= 1.9
          expect( logger.convert(invalid_utf8) ).to be === valid_utf8
        else
          pending "not supported in ruby 1.8 (using #{RUBY_VERSION})"
        end
      end
    end

    context '#generate_dated_log_folder' do

      it 'generates path for a given timestamp' do
        input_time = Time.new(2014, 6, 2, 16, 31, 22, '-07:00')
        expect( Logger.generate_dated_log_folder(test_dir, dummy_prefix, input_time) ).to be === File.join(test_dir, dummy_prefix, '2014-06-02_16_31_22')
      end

      it 'generates directory for a given timestamp' do
        input_time = Time.new(2011, 6, 10, 13, 7, 55, '-09:00')
        expect( File.directory? Logger.generate_dated_log_folder(test_dir, dummy_prefix, input_time) ).to be_truthy
      end

      it 'generates nested directories if given as a log_prefix' do
        input_time = Time.new(2011, 6, 10, 13, 7, 55, '-09:00')
        prefix = 'a/man/a/plan/a/canal/panama'
        expect( File.directory? Logger.generate_dated_log_folder(test_dir, prefix, input_time) ).to be_truthy
      end

    end

    context '#prefix_log_line' do
      def prefix_log_line_test_compare_helper(in_test, out_answer, step_in_loop=1)
        logger.instance_variable_set( :@line_prefix_length, 0 )
        step_in_loop.times { logger.step_in() }
        expect( logger.prefix_log_line(in_test) ).to be === out_answer
        logger.instance_variable_set( :@line_prefix_length, 0 )
      end

      it 'can be successfully called with a arrays' do
        line_arg = ['who done that', 'who wears da pants']
        answer_list = line_arg.map { |item| "  " + item }
        prefix_log_line_test_compare_helper(line_arg, answer_list)
      end

      it 'removes carriage returns' do
        line_arg = "  \r\n god doing this sucked"
        answer = "    \n   god doing this sucked"
        prefix_log_line_test_compare_helper(line_arg, answer)
      end

      it 'includes a newline at the end if it was on the input' do
        line_arg = "why should this matter\n"
        answer = "  why should this matter\n"
        prefix_log_line_test_compare_helper(line_arg, answer)
      end

      it 'prepends multiple lines in one string' do
        line_arg = "\n\nwhy should this matter\n"
        answer = "  \n  \n  why should this matter\n"
        prefix_log_line_test_compare_helper(line_arg, answer)
      end

      it 'can be nested' do
        line_arg = "\n\nwhy should this matter"
        answer = "      \n      \n      why should this matter"
        prefix_log_line_test_compare_helper(line_arg, answer, 3)
      end
    end

    context '#step_* methods' do
      it 'steps in correctly (simple case)' do
        logger.instance_variable_set( :@line_prefix_length, 0 )
        logger.step_in()
        expect( logger.instance_variable_get( :@line_prefix_length ) ).to be === 2
        expect( logger.line_prefix ).to be === '  '
        logger.instance_variable_set( :@line_prefix_length, 0 )
      end

      it 'sets length correctly in mixed scenario ' do
        logger.instance_variable_set( :@line_prefix_length, 0 )
        logger.step_in()
        logger.step_in()
        logger.step_out()
        logger.step_in()
        logger.step_in()
        logger.step_out()
        expect( logger.instance_variable_get( :@line_prefix_length ) ).to be === 4
        expect( logger.line_prefix ).to be === '    '
        logger.instance_variable_set( :@line_prefix_length, 0 )
      end

      it 'can be unevenly stepped out, will remain at base: 0' do
        logger.instance_variable_set( :@line_prefix_length, 0 )
        logger.step_in()
        10.times { logger.step_out() }
        expect( logger.instance_variable_get( :@line_prefix_length ) ).to be === 0
        expect( logger.line_prefix ).to be === ''
      end
    end

    context 'new' do
      it 'does not duplicate STDOUT when directly passed to it' do
        stdout_logger = Logger.new STDOUT
        expect( stdout_logger.destinations.size ).to be === 1
      end

      context 'default for' do
        its(:destinations)  { should include(STDOUT)  }
        its(:color)         { should be_nil           }
        its(:log_level)     { should be :verbose      }
      end

      context 'log_colors' do
        original_build_number = ENV['BUILD_NUMBER']

        before :each do
          ENV['BUILD_NUMBER'] = nil
        end

        after :each do
          ENV['BUILD_NUMER'] = original_build_number
        end


        it 'should have the default log_colors' do
          expect(logger.log_colors).to be == {
              :error=> Beaker::Logger::RED,
              :warn=> Beaker::Logger::BRIGHT_RED,
              :success=> Beaker::Logger::MAGENTA,
              :notify=> Beaker::Logger::BLUE,
              :info=> Beaker::Logger::GREEN,
              :debug=> Beaker::Logger::WHITE,
              :trace=> Beaker::Logger::BRIGHT_YELLOW,
              :perf=> Beaker::Logger::BRIGHT_MAGENTA,
              :host=> Beaker::Logger::YELLOW
          }
        end

        context 'when passing in log_color options' do
          let(:log_colors) {
            {
                :error => "\e[00;30m"
            }
          }

          let(:logger)     { Logger.new(my_io, :quiet => true, :log_colors => log_colors) }

          it 'should override the specified log colors' do
            expect(logger.log_colors[:error]).to be == Beaker::Logger::BLACK
          end

          it 'should leave other colors as the default' do
            expect(logger.log_colors[:warn]).to be == Beaker::Logger::BRIGHT_RED
          end
        end

        context 'with CI detected' do
          before :each do
            ENV['BUILD_NUMBER'] = 'bob'
          end

          context 'when using the default log colors' do
            it 'should override notify with NORMAL' do
              expect(logger.log_colors[:notify]).to be == Beaker::Logger::NORMAL
            end

            it 'should override info with NORMAL' do
              expect(logger.log_colors[:info]).to be == Beaker::Logger::NORMAL
            end
          end

          context 'when overriding default log colors' do
            let(:log_colors) {
              {
                  :error => "\e[00;30m"
              }
            }

            let(:logger)     { Logger.new(my_io, :quiet => true, :log_colors => log_colors) }

            it 'should override the specified log colors' do
              expect(logger.log_colors[:error]).to be == Beaker::Logger::BLACK
            end

            it 'should not override notify with NORMAL' do
              expect(logger.log_colors[:notify]).not_to be == Beaker::Logger::NORMAL
            end

            it 'should not override info with NORMAL' do
              expect(logger.log_colors[:notify]).not_to be == Beaker::Logger::NORMAL
            end
          end
        end
      end
    end

    context 'it can' do
      it 'open/create a file when a string is given to add_destination' do
        logger.add_destination 'my_tmp_file'
        expect( File.exists?( 'my_tmp_file' ) ).to be_truthy

        io = logger.destinations.select {|d| d.respond_to? :path }.first
        expect( io.path ).to match /my_tmp_file/
      end

      it 'remove destinations with the remove_destinations method' do
        logger.add_destination 'my_file'

        logger.remove_destination my_io
        logger.remove_destination 'my_file'

        expect( logger.destinations ).to be_empty
      end

      it 'strip colors from arrays of input' do
        stripped = logger.strip_colors_from [ "\e[00;30m text! \e[00;00m" ]
        expect( stripped ).to be === [ ' text! ' ]
      end

      it 'colors strings if @color is set' do
        colorized_logger = Logger.new my_io, :color => true, :quiet => true

        expect( my_io ).to receive( :print ).with "\e[00;30m"
        expect( my_io ).to receive( :print )
        expect( my_io ).to receive( :puts ).with 'my string'

        colorized_logger.optionally_color "\e[00;30m", 'my string'
      end

      context 'at trace log_level' do
        subject( :trace_logger )  { Logger.new( my_io,
                                              :log_level => 'trace',
                                              :quiet => true,
                                              :color => true )
                                  }

        its( :is_debug? ) { should be_truthy }
        its( :is_trace? ) { should be_truthy }
        its( :is_warn? )  { should be_truthy }

        context 'but print' do
          before do
            allow( my_io ).to receive :puts
            expect( my_io ).to receive( :print ).at_least :twice
          end

          it( 'warnings' )    { trace_logger.warn 'IMA WARNING!'    }
          it( 'successes' )   { trace_logger.success 'SUCCESS!'     }
          it( 'errors' )      { trace_logger.error 'ERROR!'         }
          it( 'host_output' ) { trace_logger.host_output 'ERROR!'   }
          it( 'debugs' )      { trace_logger.debug 'DEBUGGING!'     }
          it( 'traces' )      { trace_logger.trace 'TRACING!'       }
        end
      end

      context 'at verbose log_level' do
        subject( :verbose_logger )  { Logger.new( my_io,
                                              :log_level => 'verbose',
                                              :quiet => true,
                                              :color => true )
                                  }

        its( :is_trace? ) { should be_falsy }
        its( :is_debug? ) { should be_falsy }
        its( :is_verbose? ) { should be_truthy }
        its( :is_warn? )  { should be_truthy }

        context 'but print' do
          before do
            allow( my_io ).to receive :puts
            expect( my_io ).to receive( :print ).at_least :twice
          end

          it( 'warnings' )    { verbose_logger.warn 'IMA WARNING!'    }
          it( 'successes' )   { verbose_logger.success 'SUCCESS!'     }
          it( 'errors' )      { verbose_logger.error 'ERROR!'         }
          it( 'host_output' ) { verbose_logger.host_output 'ERROR!'   }
          it( 'debugs' )      { verbose_logger.debug 'NOT DEBUGGING!' }
        end
      end

      context 'at debug log_level' do
        subject( :debug_logger )  { Logger.new( my_io,
                                              :log_level => 'debug',
                                              :quiet => true,
                                              :color => true )
                                  }

        its( :is_trace? ) { should be_falsy }
        its( :is_debug? ) { should be_truthy }
        its( :is_warn? )  { should be_truthy }

        context 'successfully print' do
          before do
            allow( my_io ).to receive :puts
            expect( my_io ).to receive( :print ).at_least :twice
          end

          it( 'warnings' )    { debug_logger.warn 'IMA WARNING!'        }
          it( 'debugs' )      { debug_logger.debug 'IMA DEBUGGING!'     }
          it( 'successes' )   { debug_logger.success 'SUCCESS!'         }
          it( 'errors' )      { debug_logger.error 'ERROR!'             }
          it( 'host_output' ) { debug_logger.host_output 'ERROR!'       }
        end
      end

      context 'at info log_level' do
        subject( :info_logger ) { Logger.new( my_io,
                                              :log_level => :info,
                                              :quiet     => true,
                                              :color     => true )
                                  }

        its( :is_debug? ) { should be_falsy }
        its( :is_trace? ) { should be_falsy }


        context 'skip' do
          before do
            expect( my_io ).to_not receive :puts
            expect( my_io ).to_not receive :print
          end

          it( 'debugs' )    { info_logger.debug 'NOT DEBUGGING!' }
          it( 'traces' )    { info_logger.debug 'NOT TRACING!'   }
        end


        context 'but print' do
          before do
            expect( my_io ).to receive :puts
            expect( my_io ).to receive( :print ).twice
          end

          it( 'successes' )     { info_logger.success 'SUCCESS!'  }
          it( 'notifications' ) { info_logger.notify 'NOTFIY!'    }
          it( 'errors' )        { info_logger.error 'ERROR!'      }
        end
      end

      context 'SUT output logging' do

        context 'host output logging' do
          subject( :host_output ) { Logger.new( my_io,
                                              :log_level => :verbose,
                                              :quiet     => true,
                                              :color     => true )}

          it 'should output GREY when @color is set to true' do
            colorized_logger = host_output

            expect( my_io ).to receive( :print ).with "\e[01;30m"
            expect( my_io ).to receive( :print )
            expect( my_io ).to receive( :puts ).with 'my string'

            colorized_logger.optionally_color "\e[01;30m", 'my string'
          end

        end

        context 'color host output' do
          subject( :color_host_output ) { Logger.new( my_io,
                                              :log_level => :verbose,
                                              :quiet     => true,
                                              :color     => true )}

          it 'colors host_output' do
            colorized_logger = color_host_output

            expect( my_io ).to receive( :print ).with ""
            expect( my_io ).to receive( :puts ).with 'my string'

            colorized_logger.optionally_color "", 'my string'
          end

        end
      end

    end
  end
end
