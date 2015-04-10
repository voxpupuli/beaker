require 'beaker/answers/version30'

module Beaker
  # This class provides answer file information for PE version 3.2
  #
  # @api private
  class Version32 < Version30
    # Return answer data for all hosts.
    #
    # @return [Hash] A hash (keyed from hosts) containing hashes of answer file
    #   data.
    def generate_answers
      masterless = @options[:masterless]
      return super if masterless

      dashboard = only_host_with_role(@hosts, 'dashboard')
      database = only_host_with_role(@hosts, 'database')
      master = only_host_with_role(@hosts, 'master')

      the_answers = super
      if dashboard != master
        # in 3.2, dashboard needs the master certname
        the_answers[dashboard.name][:q_puppetmaster_certname] = master
      end

      # do we want to check for updates?
      pe_check_for_updates = answer_for(@options, :q_pe_check_for_updates, 'n')
      the_answers[dashboard.name][:q_pe_check_for_updates] = pe_check_for_updates
      the_answers[master.name][:q_pe_check_for_updates] = pe_check_for_updates

      if @options[:type] == :upgrade && dashboard != database
        # In a split configuration, there is no way for the upgrader
        # to know how much disk space is available for the database
        # migration. We tell it to continue on, because we're
        # awesome.
        the_answers[dashboard.name][:q_upgrade_with_unknown_disk_space] = 'y'
      end
      @hosts.each do |h|
        h[:answers] = the_answers[h.name]
      end
      return the_answers
    end
  end
end
