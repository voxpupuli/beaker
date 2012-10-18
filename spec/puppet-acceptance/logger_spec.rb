require 'spec_helper'

module PuppetAcceptance
  describe Logger, :use_fakefs => true do
    let(:my_io)  { MockIO.new                         }
    let(:logger) { Logger.new(my_io, :quiet => true)  }


    context 'new' do
      it 'does not duplicate STDOUT when directly passed to it' do
        stdout_logger = Logger.new STDOUT
        expect( stdout_logger ).to have(1).destinations
      end


      context 'default for' do
        its(:destinations)  { should include(STDOUT)  }
        its(:color)         { should be_nil           }
        its(:log_level)     { should be :normal       }
      end
    end


    context 'it can' do
      it 'open/create a file when a string is given to add_destination' do
        logger.add_destination 'my_tmp_file'
        expect( File.exists?( 'my_tmp_file' ) ).to be_true

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

        my_io.should_receive( :print ).with "\e[00;30m"
        my_io.should_receive( :print )
        my_io.should_receive( :puts ).with 'my string'

        colorized_logger.optionally_color "\e[00;30m", 'my string'
      end


      context 'at debug log_level' do
        subject( :debug_logger )  { Logger.new( my_io,
                                              :debug => true,
                                              :quiet => true,
                                              :color => true )
                                  }

        its( :is_debug? ) { should be_true }
        its( :is_warn? )  { should be_true }


        context 'successfully print' do
          before do
            my_io.stub :puts
            my_io.should_receive( :print ).at_least :twice
          end

          it( 'warnings' )    { debug_logger.warn 'IMA WARNING!'        }
          it( 'debugs' )      { debug_logger.debug 'IMA DEBUGGING!'     }
          it( 'successes' )   { debug_logger.success 'SUCCESS!'         }
          it( 'errors' )      { debug_logger.error 'ERROR!'             }
          it( 'host_output' ) { debug_logger.host_output 'ERROR!'       }
        end
      end

      context 'at normal log_level' do
        subject( :normal_logger ) { Logger.new( my_io,
                                              :quiet => true,
                                              :color => true )
                                  }

        its( :is_debug? ) { should be_false }
        its( :is_warn? )  { should be_false }


        context 'skip' do
          before do
            my_io.should_not_receive :puts
            my_io.should_not_receive :print
          end

          it( 'warnings' )  { normal_logger.warn 'NOT A WARNING!'  }
          it( 'debugs' )    { normal_logger.debug 'NOT DEBUGGING!' }
        end


        context 'but print' do
          before do
            my_io.should_receive :puts
            my_io.should_receive( :print ).twice
          end

          it( 'successes' )     { normal_logger.success 'SUCCESS!'  }
          it( 'notifications' ) { normal_logger.notify 'NOTFIY!'    }
          it( 'errors' )        { normal_logger.error 'ERROR!'      }
        end
      end
    end
  end
end
