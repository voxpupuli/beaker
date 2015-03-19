require 'beaker/answers/version34'

module Beaker
  # This class provides answer file information for PE version 4.0
  #
  # @api private
  class Version38 < Version34
    def generate_answers
      masterless = @options[:masterless]
      return super if masterless

      the_answers = super

      # add new answers
      exit_for_nc_migrate = answer_for(@options, :q_exit_for_nc_migrate, 'n')
      enable_future_parser = answer_for(@options, :q_enable_future_parser, 'n')

      the_answers.map do |key, value|
        # there may not be answers in the case of a windows host
        if the_answers[key]
          the_answers[key][:q_exit_for_nc_migrate] = exit_for_nc_migrate
          the_answers[key][:q_enable_future_parser] = enable_future_parser
        end
      end

      return the_answers
    end
  end
end
