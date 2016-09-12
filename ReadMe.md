# Federated Wiki - Security Plug-in: Passport

This security plug-in is written as a replacement for the Mozilla Persona plugin (wiki-security-persona). A replacement is required because the Mozilla Persona service is closing on 30th November 2016.

*To allow an orderly migration of wiki site ownership this plug-in makes use of the Mozilla Persona plug-in for Passport. This is only presented as a login option on those wiki sites that have already been claimed using Mozilla Persona. When you login with Mozilla Persona there will be a link that allows you to add an alternative identity from those the site owner has configured.*

In this release we make use of Passport's OAuth plug-ins for GitHub, Google, and Twitter. To use one, or more, of these a wiki server administrator will need to register an application with the required identity provider, and configure the wiki server. See, [configuring wiki-security-passportjs](./docs/configuration.md).
