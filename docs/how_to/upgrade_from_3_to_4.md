# `PEDefaults` and `#configure_type_defaults_on`

PEDefaults has been moved to `beaker-pe`. The call to `#configure_type_defaults_on` that was previously made in `#set_env` is no longer made. You will now need to explicitly call `#configure_type_defaults_on` in your tests when needed.
