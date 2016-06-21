
Beaker uses a set of colors to output different types of messages on to the terminal.

## The Default Color Codes
   If you do not provide any values, the defaults are: [Default colors](https://github.com/puppetlabs/beaker/blob/master/lib/beaker/logger.rb#L85-L95)

## Beaker Color Codes:
In addition, Beaker can support few other colors. List of all colors supported by Beaker:  [Colors Supported by Beaker] (https://github.com/puppetlabs/beaker/blob/master/lib/beaker/logger.rb#L14-L32)

## How to Customize:
Changes to the default options can be made by editing the configuration file.

Here are some examples:

**Eg 1: Changing color of a particular type of message**
Add the following to the hosts file to change the color of `success` messages to `GREEN` and `warning` messages to `YELLOW`. 
To get the color-code corresponding to a color, refer to: [Colors Supported by Beaker] (https://github.com/puppetlabs/beaker/blob/master/lib/beaker/logger.rb#L14-L32)

      HOSTS:
        ...
      CONFIG:
        log_colors:
          success: "\e[01;35m"
          warn: "\e[00;33m"

**Eg 2: Turning off colors.**
The following option in the hosts file will print the whole output in one single color.

      HOSTS:
        ...
      CONFIG:
        color: false
