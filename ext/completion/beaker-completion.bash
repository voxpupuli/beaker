## bash completion script for beaker

# The contained completion routines provide support for completing:
#
#    *) any option specified in beaker --help
#       but not yet the arguments to the options

# To use these routines:
#
#    1) Copy this file to somewhere (e.g. ~/.beaker-completion.sh).
#    2) Add the following line to your .bashrc/.zshrc:
#        source ~/.beaker-completion.sh
#    3) tab will now complete beaker's command line options

_beaker_complete()
{
    # COMP_WORDS is an array of words in the current command line.
    # COMP_CWORD is the index of the current word (the one the cursor is
    # in). So COMP_WORDS[COMP_CWORD] is the current word; we also record
    # the previous word here, although this specific script doesn't
    # use it yet.
    local cur_word="${COMP_WORDS[COMP_CWORD]}"
    local prev_word="${COMP_WORDS[COMP_CWORD-1]}"

    # Ask beaker to generate a list of args
    #   ensure other warnings/errors on stderr go to null
    local beaker_help=`beaker --help 2>/dev/null`

    # parse out commands and switches
    # grep extended regex, only print match
    local dash_words=`echo "${beaker_help}" | grep -oE ' \-(\w|\[|\]|-)+' | uniq`
    # parse for negated commands
    local negative_words=`echo "${dash_words}" | grep -oE '\-\-\[\w+-\](\w|-)+' | sed 's/\[//' | sed 's/\]//'`
    # remove the negative portion from dash_words
    local dash_words=`echo "${dash_words}" | sed 's/\[no\-\]//g'`

    # TODO:
    # Parse out arguments to commands
    # Perform completion if the previous word is doubledash option and current word in argslist,

    # Perform completion if the current word starts with a dash ('-'),
    if [[ ${cur_word} == -* ]] ; then
        # COMPREPLY is the array of possible completions, generated with
        # the compgen builtin.
        COMPREPLY=( $(compgen -W "${dash_words} ${negative_words}" -- ${cur_word}) )
    else
        COMPREPLY=()
    fi
    return 0
}

# Register _beaker_complete to provide completion for the following commands
complete -F _beaker_complete beaker pe-beaker
