# Federated Wiki - Security Plug-in: Passport (Configuration)

It is recommended that this plug-in is configured using a configuration file, rather than via the command line.

Configuration of Passport security plug-ins is a two stage process:

1. Registering an application with the identity provider, and
2. Configuration of the wiki software using information returned in step 1.

The legacy Mozilla Persona Passport plug-in does not require any configuration.

This plug-in comes with support for using GitHub, Google, Twitter, and generic OAuth. Although the configuration process is broadly the same for each of these, there are some slight differences.

As a wiki server owner you need to pick one, or more, of these that you want to use.

See, depending on which identity provider you choose to use:
* [GitHub](./config-github.md)
* [Google](./config-google.md)
* [Twitter](./config-twitter.md)
* [Generic OAuth](./config-oauth2.md)
