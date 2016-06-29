# Federated Wiki - Security Plug-in: Passport (Configuration)

It is recommended that this plug-in is configured using a configuration file, rather than via the command line.

Configuration of Passport security plug-ins is a two stage process:

1. Registering an application with the identity provider, and
2. Configuration of the wiki software using information returned in step 1.

The legacy Mozilla Persona Passport plug-in does not require any configuration.

This plug-in comes with support for using GitHub, Google, and Twitter. Although the configuration process is broadly the same for each of these, there are some slight differences.

As a wiki server owner you need to pick one, or more, of these that you want to use.

## GitHub

GitHub's OAuth integration only allows us to specify a single callback URL. This means that if you are running a wiki farm with multiple DNS roots, you will need to configure a separate application with GitHub for each wiki domain.

### Register an application with GitHub
You must register an application with GitHub, a new application can be created at [developer applications](https://github.com/settings/applications/new) within GitHub's settings panel. The fields needed are, `Application name`, `Homepage URL`, `Application description`, and `Authorization callback URL`. The first three will appear on the GitHub login page you get when you log into wiki, though the description is optional. The callback URL must be set to `http://example.wiki/auth/github/callback`, or if you have enabled https `https://example.wiki/auth/github/callback`, replacing `example.wiki` with the root domain for your wiki.

Your application will be issues a `client ID` and `client secret` which we will use in step 2 to configure wiki.

### Configure Wiki

The wiki is configured by adding the `client ID` and `client secret` to the wiki domain part of the configuration.

```JSON
{
  "farm": true,
  "security_type": "passportjs",
  "wikiDomains": {
    "example.wiki": {
      "github_clientID": "CLIENT ID",
      "github_clientSecret": "CLIENT SECRET"
    }
  }
}
```

## Google

### Step 1


### Step 2


## Twitter

### Step 1

### Step 2
