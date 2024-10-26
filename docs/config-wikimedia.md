## Wikimedia

MediaWiki instances running
[Extension:OAuth](https://www.mediawiki.org/wiki/Special:MyLanguage/Extension:OAuth),
including all Wikimedia wikis (like Wikipedia), can be used as an
OAuth authentication source.

### Register an application with Wikimedia

* Review the [OAuth app
  guidelines](https://meta.wikimedia.org/wiki/OAuth_app_guidelines) on
  meta.wikimedia.org.
* As described on that page, propose a new client registration at
  [Special:OAuthConsumerRegistration/propose](https://meta.wikimedia.org/wiki/Special:OAuthConsumerRegistration/propose).
  Use the "Propose an OAuth 2.0 client" link.
* Provide your wiki details:
** An application name; presumably the name of your wiki.  If you
   include "test" in the name or "localhost" in the callback URL
   the authorization will work only on your own account and only
   for 30 days.
** Set the Consumer version to `1.0`
** Describe your application; you might want to mention that the
   software is open-source and available at
   https://github.com/fedwiki/wiki-security-passportjs/
** You can click "This consumer is for use only by..." if this will
   be a single-user wiki.
** You will need to specify a callback URL.  For local testing this
   will be http://localhost:3000/auth/oauth2/callback but for a wiki
   visible to the external internet you will need to update the host
   portion.  This is a callback provided by `wiki-security-passport`.
** You will need an "Authorization code" grant type, and probably a
   "Refresh token" grant as well; you don't need "Client credentials".
** You will probably check "User identity verification only", either
   with "access to real name..." if you want to use the
   `oauth2_DisplayNameField` feature or without that otherwise.
   "Request authorization for specific permissions" is only needed if
   you are working on a deeper integration with MediaWiki.

When you click on "Propose registration" you will get a client
application key and client application secret which you will use
to create a `config.json`.  Note that you can access the details
of your registration later at
[Special:OAuthConsumerRegistration/list](https://meta.wikimedia.org/wiki/Special:OAuthConsumerRegistration/list).

### Configure Wiki

The Wiki is configured by adding the `Consumer Key` and `Consumer Secret` to the configuration. As long as we have not selected `Enable Callback Locking` these can be added outside the `wikiDomains` definition, so they apply to the entire farm. The `wikiDomains` definition is required so that the security plugin knows what is required.

This example will work for a test server running on `localhost:3000`:
```JSON
{
	"admin": {"oauth2": "ID VALUE FROM OWNER.JSON FILE OF ADMIN"},
	"security_type": "passportjs",
	"oauth2_clientID": "CLIENT APPLICATION ID",
	"oauth2_clientSecret": "CLIENT APPLICATION SECRET",
	"oauth2_CallbackURL": "http://localhost:3000/auth/oauth2/callback",
	"oauth2_AuthorizationURL": "https://www.mediawiki.org/w/rest.php/oauth2/authorize",
	"oauth2_TokenURL": "https://www.mediawiki.org/w/rest.php/oauth2/access_token",
	"oauth2_UserInfoURL": "https://www.mediawiki.org/w/rest.php/oauth2/resource/profile",
	"oauth2_UseHeader": true,
	"oauth2_IdField": "profile.sub",
	"oauth2_DisplayNameField": "profile.realname",
	"oauth2_UsernameField": "profile.username",
	"wikiDomains": {
		"localhost": {}
	}
}
```

Note that Wikimedia wikis (the global user accounts on mediawiki.org)
don't export "realname".  If you are running against a local mediawiki
instance you will need to update the `https://www.media.org/w/` prefix
to match your local install.
