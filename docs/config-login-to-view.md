# Federated Wiki - Security Plug-in: Passport
## (Configuring "Login to View")

Before attempting to configure Login to View, make sure you have already taken the steps to configure your identity provider as explained [earlier in the documentation](./configuration.md)

Where you put your configuration for the Login to View system depends on which sites on your farm you want to be restricted.  If you want the whole farm to be restricted then you would add the key-value pairs into the top level of your wiki's `config.json`. If you only want to restrict specific sites on your farm, then you need to restrict them individually within a wikiDomains section of your config.

The properties we need to add for Login to View are: `restricted`, `details`, and either `allowed_domains` (Google) or `allowed_ids`  (GitHub, Twitter, OAuth2) depending on your identity provider.

**Examples:**

If your identity provider is **Google**:
```json
{
  "admin": {"google":"105396921212328672315"},
  "farm": true,
  "cookieSecret": "0ebf86563b4sdfsdfcc8788e666702",
  "secure_cookie": true,
  "security_type": "passportjs",
  "security_useHttps": true,
  "allowed": "*",
  "wikiDomains": {
    "private.example.com": {
      "admin": {"google":"105396921212328672315"},
      "google_clientID": "10030fghfgh7443-gcemshdl37j67mgpm99eu5dh43li5vrs.apps.googleusercontent.com",
      "google_clientSecret": "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",
      "restricted": true,
      "details": "http://path.ward.asia.wiki.org/login-to-view.html",
      "allowed_domains": [
        "c2.com",
        "ustawimovement.global",
        "catalystlearninglabs.org",
        "robert.best",
                "wiki.cafe"
      ]
    }
  }
}
```

If your identity provider is **GitHub**, **Twitter**, or generic **OAuth2**:
```json
{
    "admin": {"oauth2": "admin"},
    "farm": true,
    "cookieSecret": "FDpmzFT2FQZsdfsdfFr4WwZFGuwuVSQ",
    "secure_cookie": true,
    "security_type": "passportjs",
    "security_useHttps": true,
    "allowed": "*",
    "wikiDomains": {
      "wiki.example.com": {
        "oauth2_DisplayNameField": "token.preferred_username",
        "oauth2_IdField": "token.preferred_username",
        "oauth2_clientID": "wiki",
        "oauth2_clientSecret": "3Df5D3jNfsdfsdfsdfNvc08iJOL3uSCg",
        "oauth2_AuthorizationURL": "https://auth.example.com/realms/wiki-cafe-test-server/protocol/openid-connect/auth",
        "oauth2_TokenURL": "https://auth.example.com/realms/wiki-cafe-test-server/protocol/openid-connect/token",
        "oauth2_UsernameField": "token.preferred_username",
        "restricted": true,
        "details": "http://path.ward.asia.wiki.org/login-to-view.html",
        "allowed_ids": ["*"]
      }
    }
  }
  ```