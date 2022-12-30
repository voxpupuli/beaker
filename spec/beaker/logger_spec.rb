# encoding: UTF-8
require 'spec_helper'

module Beaker
  describe Logger do
    let(:my_io)     { StringIO.new                         }
    let(:logger)    { described_class.new(my_io, :quiet => true)  }
    let(:basic_logger)    { described_class.new(:quiet => true)  }
    let(:test_dir)  { 'tmp/tests' }
    let(:dummy_prefix)  { 'dummy' }

    describe '#convert' do
      let(:valid_utf8)  { "/etc/puppet/modules\n├── jimmy-appleseed (\e[0;36mv1.1.0\e[0m)\n├── jimmy-crakorn (\e[0;36mv0.4.0\e[0m)\n└── jimmy-thelock (\e[0;36mv1.0.0\e[0m)\n" }
      let(:invalid_utf8) {"/etc/puppet/modules\n├── jimmy-appleseed (\e[0;36mv1.1.0\e[0m)\n├── jimmy-crakorn (\e[0;36mv0.4.0\e[0m)\n└── jimmy-thelock (\e[0;36mv1.0.0\e[0m)\xAD\n"}

      it 'preserves valid utf-8 strings' do
        expect( logger.convert(valid_utf8) ).to be === valid_utf8
      end

      it 'strips out invalid utf-8 characters' do
        expect( logger.convert(invalid_utf8) ).to be === valid_utf8
      end

      it 'supports frozen strings' do
        valid_utf8.freeze
        expect( logger.convert(valid_utf8) ).to be === valid_utf8
      end
    end

    describe '#generate_dated_log_folder' do

      it 'generates path for a given timestamp' do
        input_time = Time.new(2014, 6, 2, 16, 31, 22, '-07:00')
        expect( described_class.generate_dated_log_folder(test_dir, dummy_prefix, input_time) ).to be === File.join(test_dir, dummy_prefix, '2014-06-02_16_31_22')
      end

      it 'generates directory for a given timestamp' do
        input_time = Time.new(2011, 6, 10, 13, 7, 55, '-09:00')
        expect( File ).to be_directory described_class.generate_dated_log_folder(test_dir, dummy_prefix, input_time)
      end

      it 'generates nested directories if given as a log_prefix' do
        input_time = Time.new(2011, 6, 10, 13, 7, 55, '-09:00')
        prefix = 'a/man/a/plan/a/canal/panama'
        expect( File ).to be_directory described_class.generate_dated_log_folder(test_dir, prefix, input_time)
      end

    end

    describe '#prefix_log_line' do
      around do |example|
        logger.line_prefix = ''
        begin
          example.run
        ensure
          logger.line_prefix = ''
        end
      end

      def prefix_log_line_test_compare_helper(in_test, out_answer)
        logger.with_indent do
          expect( logger.prefix_log_line(in_test) ).to be === out_answer
        end
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
        logger.with_indent do
          logger.with_indent do
            logger.with_indent do
              expect( logger.prefix_log_line(line_arg) ).to be === answer
            end
          end
        end
      end
    end

    context 'when indenting' do
      around do |example|
        logger.line_prefix = ''
        begin
          example.run
        ensure
          logger.line_prefix = ''
        end
      end

      it 'steps in correctly (simple case)' do
        logger.with_indent do
          expect( logger.line_prefix ).to be === '  '
        end
      end

      it 'sets length correctly in mixed scenario ' do
        logger.with_indent do
          logger.with_indent {}
          logger.with_indent do
            logger.with_indent {}
            expect( logger.line_prefix ).to be === '    '
          end
        end
      end

      it 'can handle arbitrary strings as prefixes' do
        logger.line_prefix = 'Some string:'
        expect( logger.line_prefix ).to be === 'Some string:'
      end

      it 'can handle stepping in with arbitrary strings' do
        logger.line_prefix = 'Some string:'
        logger.with_indent do
          logger.with_indent do
            expect( logger.line_prefix ).to be === 'Some string:    '
          end
        end
      end

      it 'can handle stepping in and out with arbitrary strings' do
        logger.line_prefix = 'Some string:'
        10.times { logger.with_indent {} }
        expect( logger.line_prefix ).to be === 'Some string:'
      end

      it 'restores the original prefix if an argument is raised' do
        logger.line_prefix = 'Some string:'
        expect do
          logger.with_indent do
            raise "whoops"
          end
        end.to raise_error(RuntimeError, 'whoops')
        expect(logger.line_prefix).to eq('Some string:')
      end
    end

    context 'new' do
      it 'does not duplicate STDOUT when directly passed to it' do
        stdout_logger = described_class.new STDOUT
        expect( stdout_logger.destinations.size ).to be === 1
      end

      context 'default for' do
        its(:destinations)  { is_expected.to include(STDOUT)  }
        its(:color)         { is_expected.to be_nil           }
        its(:log_level)     { is_expected.to be :verbose      }
      end

      context 'log_colors' do
        original_build_number = ENV['BUILD_NUMBER']

        before do
          ENV['BUILD_NUMBER'] = nil
        end

        after do
          ENV['BUILD_NUMER'] = original_build_number
        end


        it 'has the default log_colors' do
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

          let(:logger)     { described_class.new(my_io, :quiet => true, :log_colors => log_colors) }

          it 'overrides the specified log colors' do
            expect(logger.log_colors[:error]).to be == Beaker::Logger::BLACK
          end

          it 'leaves other colors as the default' do
            expect(logger.log_colors[:warn]).to be == Beaker::Logger::BRIGHT_RED
          end
        end

        context 'with CI detected' do
          before do
            ENV['BUILD_NUMBER'] = 'bob'
          end

          context 'when using the default log colors' do
            it 'overrides notify with NORMAL' do
              expect(logger.log_colors[:notify]).to be == Beaker::Logger::NORMAL
            end

            it 'overrides info with NORMAL' do
              expect(logger.log_colors[:info]).to be == Beaker::Logger::NORMAL
            end
          end

          context 'when overriding default log colors' do
            let(:log_colors) {
              {
                  :error => "\e[00;30m"
              }
            }

            let(:logger)     { described_class.new(my_io, :quiet => true, :log_colors => log_colors) }

            it 'overrides the specified log colors' do
              expect(logger.log_colors[:error]).to be == Beaker::Logger::BLACK
            end

            it 'does not override notify with NORMAL' do
              expect(logger.log_colors[:notify]).not_to be == Beaker::Logger::NORMAL
            end

            it 'does not override info with NORMAL' do
              expect(logger.log_colors[:notify]).not_to be == Beaker::Logger::NORMAL
            end
          end
        end
      end
    end

    context 'it can' do
      it 'open/create a file when a string is given to add_destination' do
        logger.add_destination 'my_tmp_file'
        expect( File ).to exist( 'my_tmp_file' )

        io = logger.destinations.find {|d| d.respond_to? :path }
        expect( io.path ).to match(/my_tmp_file/)
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
        colorized_logger = described_class.new my_io, :color => true, :quiet => true

        expect( my_io ).to receive( :print ).with "\e[00;30m"
        expect( my_io ).to receive( :print )
        expect( my_io ).to receive( :puts ).with 'my string'

        colorized_logger.optionally_color "\e[00;30m", 'my string'
      end

      context 'at trace log_level' do
        subject( :trace_logger )  { described_class.new( my_io,
                                              :log_level => 'trace',
                                              :quiet => true,
                                              :color => true )
                                  }

        its( :is_debug? ) { is_expected.to be_truthy }
        its( :is_trace? ) { is_expected.to be_truthy }
        its( :is_warn? )  { is_expected.to be_truthy }

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
        subject( :verbose_logger )  { described_class.new( my_io,
                                              :log_level => 'verbose',
                                              :quiet => true,
                                              :color => true )
                                  }

        its( :is_trace? ) { is_expected.to be_falsy }
        its( :is_debug? ) { is_expected.to be_falsy }
        its( :is_verbose? ) { is_expected.to be_truthy }
        its( :is_warn? )  { is_expected.to be_truthy }

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
        subject( :debug_logger )  { described_class.new( my_io,
                                              :log_level => 'debug',
                                              :quiet => true,
                                              :color => true )
                                  }

        its( :is_trace? ) { is_expected.to be_falsy }
        its( :is_debug? ) { is_expected.to be_truthy }
        its( :is_warn? )  { is_expected.to be_truthy }

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
        subject( :info_logger ) { described_class.new( my_io,
                                              :log_level => :info,
                                              :quiet     => true,
                                              :color     => true )
                                  }

        its( :is_debug? ) { is_expected.to be_falsy }
        its( :is_trace? ) { is_expected.to be_falsy }


        context 'skip' do
          before do
            expect( my_io ).not_to receive :puts
            expect( my_io ).not_to receive :print
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
          subject( :host_output ) { described_class.new( my_io,
                                              :log_level => :verbose,
                                              :quiet     => true,
                                              :color     => true )}

          it 'outputs GREY when @color is set to true' do
            colorized_logger = host_output

            expect( my_io ).to receive( :print ).with "\e[01;30m"
            expect( my_io ).to receive( :print )
            expect( my_io ).to receive( :puts ).with 'my string'

            colorized_logger.optionally_color "\e[01;30m", 'my string'
          end

        end

        context 'color host output' do
          subject( :color_host_output ) { described_class.new( my_io,
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
