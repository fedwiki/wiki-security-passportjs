# Federated Wiki - Security Plug-in: Passport (Configuring "Login to View")

Before attempting to configure Login to View, make sure you have already taken the steps to configure your identity provider as explained [earlier in the documentation](./configuration.md)

Where you put your configuration for the Login to View system depends on which sites on your farm you want to be restricted.  If you want the whole farm to be restricted then you would add the key-value pairs into the top level of your wiki's `config.json`. If you only want to restrict specific sites on your farm, then you need to restrict them individually within a wikiDomains section of your config.

The properties we need to add for Login to View are: `details`, `details`, and either `allowed_domains` or `allowed_usernames` depending on your identity provider.

Examples:

If your identity provider is Google:


If your identity provider is GitHub, Twitter, or generic OAuth2: