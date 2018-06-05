# How to Use Hocon Helpers

Beaker provides a few convenience methods to help you use the [HOCON](https://github.com/typesafehub/config/blob/master/HOCON.md) configuration file format in your testing. This doc will give you an overview of what each method does, but if you'd like more in-depth information, please checkout our [Hocon Helpers Rubydocs](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HoconHelpers).

## hocon_file_read_on

If you'd just like to read the contents of a HOCON file from a System Under Test (SUT), this is the method for you. Note that you will get back a [ConfigValueFactory object](https://github.com/puppetlabs/ruby-hocon#basic-usage) like in the other helper methods here.

## hocon_file_edit_in_place_on

This method is specifically for editing a file on a SUT and saving it in-place, meaning it'll save your changes in the place of the original file you read from.

The special thing to take note of here is that the Proc you pass to this method will need to return the doc that you'd like saved in order for saving to work as specified.

## hocon_file_edit_on

This method is our generic open-ended method for editing a file from a SUT. This is the most flexible method, doing nothing but providing you with the contents of the file to edit yourself.

This does not save the file edited. Our recommendation is to use the [`create_remote_file` method](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HostHelpers#create_remote_file-instance_method), as shown in the [Rubydocs example](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Helpers/HoconHelpers#hocon_file_edit_on-instance_method) if you'd like to save. This allows us to have more flexibility to do things such as moving the edited file to back up or version your changes.
