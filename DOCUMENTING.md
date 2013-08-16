
## Contributing Documentation to Puppetlabs Test Harness ##


All inline documentation uses YARD, below is an example usage, a quick
summary of documentation expectations and finally a short reference
for those new to YARD.

They say a picture is worth a thousand words, hopefully this example will
be worth more than the 154 it’s composed of:
```ruby

    #
    # @param  [Array<Host>, Host, #execute] hosts    The host(s) to act on
    # @param  [String]                      action   The action to perform
    # @param  [Hash{Symbol=>String}]        options  The options hash
    #   @option [Boolean] :noop    (false)  Set to true if you want noop mode
    #   @option [Boolean] :verbose (true)   Whether or not to log verbosely
    #
    # @yield  [result] Yields the result of action for further checking
    #   @yieldparam [Result] result A ValueObject containing action stats
    # @return [void] This method is a helper for remotely executing tasks
    #
    # @example Use this method when action must be sudone
    #     sudo_with_logging( master, ‘reboot -r’, :verbose => false )
    #
    # @example Pass this a block to perform additional checks
    #     sudo_with_logging( master, ‘apt-get update’ ) do |result|
    #       if result.exit_code == 1
    #         fail_test( ‘Apt has failed us again!’ )
    #       end
    #     end
    #
    # @see TestCase#on
    # @api dsl
    #
    def sudo_with_logging hosts, action, options = {}, &block
      return if options[:noop]

      if hosts.is_a?( Array )
        hosts.each {|h| sudo_with_logging h, action, options, &block }
      else
        result = host.execute( action, options.delete(:verbose) )
        yield result if block_given?
      end
    end

```


## Documentation Guide: ##


Most of our documentation is done with the @tag syntax. With a few
execptions tags follow this format:

    @tag [TypeOfValueInBrackets] nameOfValue Multi-word description that
      can span multiple lines, as long as lines after the first have
      greater indentation

Note: The `tag` name and the `nameOfValue` in question cannot contain spaces.

All sections should be considered mandatory, but in practice a committer
can walk a contributor through the process and help ensure a high quality
of documentation.  When contributing keep especially in mind that an
`@example` block will go a long way in helping understand the use case
(which also encourages use by others) and the @api tag helps to understand
the scope of a Pull Request.

Please be liberal with whitespace (not trailing whitespace) and vertical
alignment as it helps readability while “in code”. Default indentation
is two spaces unless there are readability/vertical alignment concerns.

While the `@params`, `@returns`, etc... may seem redundant they encourage
thinking through exactly what you are doing and because of their strict
format they allow a level of tooling not available in regular ruby.

You are encouraged to run the YARD documentation server locally by:

    rake docs

or

    rake docs:bg

depending on whether you want the server to run in the foreground or not

Wait for the documentation to compile and then point your browser to:

    http://localhost:8808


## A Simple YARD Reference: ##


A Hash that must be in `{:symbol => ‘string’}` format:

    @param [Hash<Symbol, String>] my_hash

This is also valid, and maybe more obvious to those used to Ruby

    @param [Hash{Symbol=>String}]

When specifying an options hash you use @option to specify key/values

    @param [Hash{Symbol=>String}] my_opts An options hash
    @option my_opts [ClassOfValue] :key_in_question A Description
    @option my_opts [Fixnum]       :log_level       The log level to run in.
    @option my_opts [Boolean]      :turbo (true)    Who doesn’t want turbos?

This parameter takes an unordered list of Strings, Fixnums, and Floats

    @param [Array<String, Fixnum, Float>]

This is an ordered list of String, then Fixnum

    @param [Array<(String, Fixnum)>]

This is a parameter that needs to implement certain methods

    @param [#[], #to_s]

This documents that a method may return any of the types listed

    @return [String, self, nil]

This is the return statement for a method only used for side effects

    @return [void]

If a method returns a boolean (TrueClass or FalseClass) write:

    @return [Boolean]

List possible classes that the method may raise:

    @raise [Beaker::PendingTest]

List parameter names yielded by a method

    @yield [result, self]

And specify what kind of object is yielded with this

    @yieldparam [Result] result

An `example` block contains a tag, description and then indented code:

    @example Accessing Host defaults using hash syntax
        host[‘platform’]  #=> ‘debian-6-amd64’

The `api` tag can have anything behind it, please use the following
when documenting harness methods:

    @api dsl        Part of the testing dsl used within tests
    @api public     Methods third party integrations can rely on
    @api private    Methods private to the harness, not to be used externally

When deprecating a method include information on newer alternatives

    @deprecated This method is horrible. Please use {#foo} or {#bar}.

When you want to reference other information use

    @see ClassOrModule
    @see http://web.url.com/reference Title for the link

