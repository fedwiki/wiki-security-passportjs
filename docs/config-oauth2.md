## Generic OAuth 2

### Login provider set-up

Like the other PassportJS login providers, we'll need a separate "OAuth2 Client"
(others call it an "app", a "product" etc.) for our Federated Wiki instance.

How to do this varies slightly for each provider.

### `config.json`

In general, you will need to specify:
* `oauth2_clientID` -- some systems generate this for you, others allow you to
    specify it
* `oauth2_clientSecret` -- secure key (keep this secret!)
* `oauth2_AuthorizationURL` and `oauth2_TokenURL` -- from your login provider's documentation

You will also need to specify a callback URL. For some providers, you can add
this when making a new "OAuth Client" for your wiki, for others you will need to
specify it with `oauth2_CallbackURL`.

You might also need to tell Federated Wiki how to look up usernames:
* `oauth2_UserInfoURL` -- from login provider's documentation
* `oauth2_IdField`, `oauth2_DisplayNameField`, `oauth2_UsernameField` -- starting with 
  * `params` for information returned in the original token request, or
  * `profile` for data returned from `oauth2_UserInfoURL`, if you provided it.

Sometimes, you'll be able to look up the URLs by visiting your provider's
`/.well-known/openid-configuration` URL in a web browser.

### Examples

#### Nextcloud

```JSON
{
  "farm": true,
  "admin": {"oauth2": "ID VALUE FROM OWNER.JSON FILE OF ADMIN"},
  "security_type": "passportjs",
  "oauth2_clientID": "CLIENT ID",
  "oauth2_clientSecret": "CLIENT SECRET",
  "oauth2_AuthorizationURL": "https://auth.example.com/oauth2/authorize",
  "oauth2_TokenURL": "https://auth.example.com/oauth2/token",
}
```

#### Keycloak

```JSON
{
  "farm": true,
  "admin": {"oauth2": "ID VALUE FROM OWNER.JSON FILE OF ADMIN"},
  "security_type": "passportjs",
  "oauth2_clientID": "CLIENT ID",
  "oauth2_clientSecret": "CLIENT SECRET",
  "oauth2_AuthorizationURL": "https://auth.example.com/auth/realms/Wiki.Cafe/protocol/openid-connect/auth",
  "oauth2_TokenURL": "https://auth.example.com/auth/realms/Wiki.Cafe/protocol/openid-connect/token",
  "oauth2_UserInfoURL": "https://auth.example.com/auth/realms/Wiki.Cafe/protocol/openid-connect/userinfo",
  "oauth2_UsernameField": "profile.preferred_username"
}
```
