###
 * Federated Wiki : Security Plugin : Social
 *
 * Copyright Ward Cunningham and other contributors
 * Licensed under the MIT license.
 * https://github.com/fedwiki/wiki-security-social/blob/master/LICENSE.txt
###

#### Requires ####
fs = require 'fs'
path = require 'path'

https = require 'https'
qs = require 'qs'

url = require 'url'

_ = require 'lodash'
glob = require 'glob'

passport = require('passport')

# Export a function that generates security handler
# when called with options object.
module.exports = exports = (log, loga, argv) ->
  security = {}

#### Private stuff ####

  owner = ''
  ownerName = ''
  user = {}
  wikiName = argv.url
  wikiHost = argv.wiki_domain

  admin = argv.admin

  statusDir = argv.status

  idFile = argv.id
  usingPersona = false

  if argv.security_useHttps
    useHttps = true
    callbackProtocol = "https:"
  else
    useHttps = false
    callbackProtocol = url.parse(argv.url).protocol

  if wikiHost
    callbackHost = wikiHost
    if url.parse(argv.url).port
      callbackHost = callbackHost + ":" + url.parse(argv.url).port
  else
    callbackHost = url.parse(argv.url).host

  ids = []

  # Mozilla Persona service closes on
  personaEnd = new Date('2016-11-30')

  watchForOwnerChange = ->
    # we watch for owner changes, so we can update the information held here
    fs.watch(idFile, (eventType, filename) ->
      # re-read the owner file
      fs.readFile(idFile, (err, data) ->
        if err
          console.log 'Error reading ', idFile, err
          return
        owner = JSON.parse(data)
        usingPersona = false
        if _.isEmpty(_.intersection(_.keys(owner), ids))
          if _.has(owner, 'persona')
            usingPersona = true
        ownerName = owner.name
      )
    )

  #### Public stuff ####

  # Attempt to figure out if the wiki is claimed or not,
  # if it is return the owner.

  security.retrieveOwner = (cb) ->
    fs.exists idFile, (exists) ->
      if exists
        fs.readFile(idFile, (err, data) ->
          if err then return cb err
          owner = JSON.parse(data)
          # we only enable persona if it is the only owner information.
          if _.isEmpty(_.intersection(_.keys(owner), ids))
            if _.has(owner, 'persona')
              usingPersona = true
          watchForOwnerChange()
          cb())
      else
        owner = ''
        cb()

  security.getOwner = getOwner = ->
    if !owner.name?
      ownerName = ''
    else
      ownerName = owner.name
    ownerName

  security.setOwner = setOwner = (id, cb) ->
    fs.exists idFile, (exists) ->
      if !exists
        fs.writeFile(idFile, JSON.stringify(id), (err) ->
          if err then return cb err
          console.log "Claiming wiki #{wikiName} for #{id}"
          owner = id
          ownerName = owner.name
          watchForOwnerChange()
          cb())
      else
        cb('Already Claimed')

  security.getUser = getUser = (req) ->
    if req.session.passport
      if req.session.passport.user
        return req.session.passport.user
      else
        return ''
    else
      return ''

  security.isAuthorized = isAuthorized = (req) ->
    if owner is ''
      console.log 'isAuthorized: site not claimed'
      return true
    else
      try
        idProvider = _.head(_.keys(req.session.passport.user))
        switch idProvider
          when 'github', 'google', 'twitter'
            if _.isEqual(owner[idProvider].id, req.session.passport.user[idProvider].id)
              return true
            else
              return false
          when 'persona'
            if _.isEqual(owner[idProvider].email, req.session.passport.user[idProvider].email)
              return true
            else
              return false
          else
            return false
      catch error
        return false


  security.isAdmin = (req) ->
    return false if admin is undefined
    try
      return false if req.session.passport.user is undefined
    catch
      return false

    idProvider = _.head(_.keys(req.session.passport.user))

    if admin[idProvider] is undefined
      console.log 'admin not defined for ', idProvider
      return false

    switch idProvider
      when "github", "google", "twitter"
        if _.isEqual(admin[idProvider], req.session.passport.user[idProvider].id)
          return true
        else
          return false
      when "persona"
        if _.isEqual(admin[idProvider], req.session.passport.user[idProvider].email)
          return true
        else
          return false
      else
        return false


  security.login = (updateOwner) ->
    console.log "Login...."

  security.logout = () ->
    (req, res) ->
      console.log "Logout...."

  security.defineRoutes = (app, cors, updateOwner) ->

    passport.serializeUser = (user, req, done) ->
      done(null, user)

    passport.deserializeUser = (obj, req, done) ->
      done(null, obj)

    # Github Strategy
    if argv.github_clientID? and argv.github_clientSecret?
      ids.push('github')
      GithubStrategy = require('passport-github').Strategy

      githubStrategyName = callbackHost + 'Github'

      passport.use(githubStrategyName, new GithubStrategy({
        clientID: argv.github_clientID
        clientSecret: argv.github_clientSecret
        scope: 'user:emails'
        # callbackURL is optional, and if it exists must match that given in
        # the OAuth application settings - so we don't specify it.
        }, (accessToken, refreshToken, profile, cb) ->
          user.github = {
            id: profile.id
            username: profile.username
            displayName: profile.displayName
            emails: profile.emails
          }
          cb(null, user)))

    # Twitter Strategy
    if argv.twitter_consumerKey? and argv.twitter_consumerSecret?
      ids.push('twitter')
      TwitterStrategy = require('passport-twitter').Strategy

      twitterStrategyName = callbackHost + 'Twitter'

      passport.use(twitterStrategyName, new TwitterStrategy({
        consumerKey: argv.twitter_consumerKey
        consumerSecret: argv.twitter_consumerSecret
        callbackURL: callbackProtocol + '//' + callbackHost + '/auth/twitter/callback'
        }, (accessToken, refreshToken, profile, cb) ->
          user.twitter = {
            id: profile.id
            username: profile.username
            displayName: profile.displayName
          }
          cb(null, user)))

    # Google Strategy
    if argv.google_clientID? and argv.google_clientSecret?
      ids.push('google')
      GoogleStrategy = require('passport-google-oauth20').Strategy

      googleStrategyName = callbackHost + 'Google'

      passport.use(googleStrategyName, new GoogleStrategy({
        clientID: argv.google_clientID
        clientSecret: argv.google_clientSecret
        callbackURL: callbackProtocol + '//' + callbackHost + '/auth/google/callback'
        }, (accessToken, refreshToken, profile, cb) ->
          user.google = {
            id: profile.id
            displayName: profile.displayName
            emails: profile.emails
          }
          cb(null, user)))

    # Persona Strategy
    PersonaStrategy = require('persona-pass').Strategy

    personaAudience = callbackProtocol + '//' + callbackHost

    personaStrategyName = callbackHost + 'Persona'

    passport.use(personaStrategyName, new PersonaStrategy({
      audience: personaAudience
      }, (email, cb) ->
        user = {
          persona: {
            email: email
          }
        }
        cb(null, user)))


    app.use(passport.initialize())
    app.use(passport.session())

    # Github
    app.get('/auth/github', passport.authenticate(githubStrategyName, {scope: 'user:email'}), (req, res) -> )
    app.get('/auth/github/callback',
      passport.authenticate(githubStrategyName, { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))

    # Twitter
    app.get('/auth/twitter', passport.authenticate(twitterStrategyName), (req, res) -> )
    app.get('/auth/twitter/callback',
      passport.authenticate(twitterStrategyName, { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))

    # Google
    app.get('/auth/google', passport.authenticate(googleStrategyName, { scope: [
      'https://www.googleapis.com/auth/plus.profile.emails.read'
      ]}))
    app.get('/auth/google/callback',
      passport.authenticate(googleStrategyName, { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))

    # Persona
    app.post('/auth/browserid',
      passport.authenticate(personaStrategyName, { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))


    app.get '/auth/client-settings.json', (req, res) ->
      # the client needs some information to configure itself
      settings = {
        useHttps: useHttps
        usingPersona: usingPersona
      }
      if wikiHost
        settings.wikiHost = wikiHost
      res.json settings

    app.get '/auth/loginDialog', (req, res) ->
      referer = req.headers.referer
      schemeButtons = []
      _(ids).forEach (scheme) ->
        switch scheme
          when "twitter" then schemeButtons.push({button: "<a href='/auth/twitter' class='scheme-button twitter-button'><span>Twitter</span></a>"})
          when "github" then schemeButtons.push({button: "<a href='/auth/github' class='scheme-button github-button'><span>Github</span></a>"})
          when "google" then schemeButtons.push({button: "<a href='/auth/google' class='scheme-button google-button'><span>Google</span></a>"})

      info = {
        wikiName: if useHttps
          url.parse(referer).hostname
        else
          url.parse(referer).host
        wikiHostName: if wikiHost
          "part of " + req.hostname + " wiki farm"
        else
          "a federated wiki site"
        title: "Federated Wiki: Site Owner Sign-on"
        loginText: "Sign in to"
        schemes: schemeButtons
      }
      res.render(path.join(__dirname, '..', 'views', 'securityDialog.html'), info)

    app.get '/auth/personaLogin', (req, res) ->
      referer = req.headers.referer
      schemeButtons = []
      if Date.now() < personaEnd
        schemeButtons.push({
          button: "<a href='#' id='browserid' class='scheme-button persona-button'><span>Persona</span></a>
                   <script>
                    $('#browserid').click(function(){
                      navigator.id.get(function(assertion) {
                        if (assertion) {
                          $('input').val(assertion);
                          $('form').submit();
                        } else {
                          location.reload();
                        }
                      });
                    });
                   </script>"})
        info = {
          wikiName: if useHttps
            url.parse(referer).hostname
          else
            url.parse(referer).host
          wikiHostName: if wikiHost
            "part of " + req.hostname + " wiki farm"
          else
            "a federated wiki site"
          title: "Federated Wiki: Site Owner Sign-on"
          loginText: "Sign in to"
          message: "Mozilla Persona closes on 30th November 2016. Wiki owners should add an alternative identity as soon as they are able."
          schemes: schemeButtons
        }
      else
        info = {
          wikiName: if useHttps
            url.parse(referer).hostname
          else
            url.parse(referer).host
          wikiHostName: if wikiHost
            "part of " + req.hostname + " wiki farm"
          else
            "a federated wiki site"
          title: "Federated Wiki: Site Owner Sign-on"
          message: "Mozilla Persona has now closed. Wiki owners will need to contact the Wiki Farm owner to re-claim their wiki."
        }
      res.render(path.join(__dirname, '..', 'views', 'personaDialog.html'), info)

    app.get '/auth/loginDone', (req, res) ->
      referer = req.headers.referer
      if referer is undefined
        referer = ''

      info = {
        wikiName: if useHttps
          url.parse(referer).hostname
        else
          url.parse(referer).host
        wikiHostName: if wikiHost
          "part of " + req.hostname + " wiki farm"
        else
          "a federated wiki site"
        title: if owner
          "Wiki Site Owner Sign-on"
        else
          "Sign-on to claim Wiki site"
        owner: getOwner
        authMessage: "You are now logged in<br>If this window hasn't closed, you can close it."
      }
      res.render(path.join(__dirname, '..', 'views', 'done.html'), info)

    app.get '/auth/addAuthDialog', (req, res) ->
      # only makes sense to add alternative authentication scheme if
      # this the user is authenticated
      user = getUser(req)
      if user
        referer = req.headers.referer

        currentSchemes = _.keys(user)
        altSchemes = _.difference(ids, currentSchemes)

        schemeButtons = []
        _(altSchemes).forEach (scheme) ->
          switch scheme
            when "twitter" then schemeButtons.push({button: "<a href='/auth/twitter' class='scheme-button twitter-button'><span>Twitter</span></a>"})
            when "github" then schemeButtons.push({button: "<a href='/auth/github' class='scheme-button github-button'><span>Github</span></a>"})
            when "google" then schemeButtons.push({button: "<a href='/auth/google' class='scheme-button google-button'><span>Google</span></a>"})

        info = {
          wikiName: if useHttps
            url.parse(referer).hostname
          else
            url.parse(referer).host
          wikiHostName: if wikiHost
            "part of " + req.hostname + " wiki farm"
          else
            "a federated wiki site"
          title: "Federated Wiki: Add Alternative Authentication Scheme"
          schemes: schemeButtons
        }
        res.render(path.join(__dirname, '..', 'views', 'addAlternativeDialog.html'), info)

      else
        # user is not authenticated
        res.sendStatus(403)

    authorized = (req, res, next) ->
      if isAuthorized(req)
        next()
      else
        console.log 'rejecting - not authorized', req.path
        res.sendStatus(403)

    app.get '/auth/addAltAuth', authorized, (req, res) ->
      # add alternative authorentication scheme - only makes sense if user owns this site
      res.status(202).end()

      user = req.session.passport.user

      idProviders = _.keys(user)
      userIds = {}
      idProviders.forEach (idProvider) ->
        id = switch idProvider
          when "twitter" then {
            name: user.twitter.displayName
            twitter: {
              id: user.twitter.id
              username: user.twitter.username
            }
          }
          when "github" then {
            name: user.github.displayName
            github: {
              id: user.github.id
              username: user.github.username
              email: user.github.emails
            }
          }
          when "google" then {
            name: user.google.displayName
            google: {
              id: user.google.id
              emails: user.google.emails
            }
          }
          # only needed until persona closes
          when "persona" then {
            name: user.persona.email
              .substr(0, user.persona.email.indexOf('@'))
              .split('.')
              .join(' ')
              .toLowerCase()
              .replace(/(^| )(\w)/g, (x) ->
                return x.toUpperCase())
            persona: {
              email: user.persona.email
            }
          }
        userIds = _.merge(userIds, id)

      wikiDir = path.resolve(argv.data, '..')
      statusDir = argv.status.split(path.sep).slice(-1)[0]
      idFileName = path.parse(idFile).base

      pattern = '*/' + statusDir + '/' + idFileName

      glob(pattern, {cwd: wikiDir}, (err, files) ->
        _.forEach files, (file) ->
          # are we the owner?
          fs.readFile(path.join(wikiDir, file), 'utf8', (err, data) ->
            if err
              console.log 'Error reading ', file, err
              return
            siteOwner = JSON.parse(data)

            if _.intersectionWith(_.entries(siteOwner), _.entries(user), _.isEqual).length > 0
              updateOwner = _.merge(user, siteOwner)
              fs.writeFile(path.join(wikiDir, file), JSON.stringify(userIds), (err) ->
                if err
                  console.log 'Error writing ', file, err
                # if the write works the change will be picked up by fs.watch() in watchForOwnerChange
                # so there is nothing more to do here.
              )
          )
        )


    app.get '/auth/claim-wiki', (req, res) ->
      if owner
        console.log 'Claim Request Ignored: Wiki already has owner - ', wikiName
        res.sendStatus(403)
      else
        user = req.session.passport.user
        # there can be more than one id provider - initially only if we logged in with persona
        idProviders = _.keys(user)

        id = {}
        idProviders.forEach (idProvider) ->
          id = switch idProvider
            when "twitter" then {
              name: user.twitter.displayName
              twitter: {
                id: user.twitter.id
                username: user.twitter.username
              }
            }
            when "github" then {
              name: user.github.displayName
              github: {
                id: user.github.id
                username: user.github.username
                email: user.github.emails
              }
            }
            when "google" then {
              name: user.google.displayName
              google: {
                id: user.google.id
                emails: user.google.emails
              }
            }
            # only needed until persona closes
            when "persona" then {
              name: user.persona.email
                .substr(0, user.persona.email.indexOf('@'))
                .split('.')
                .join(' ')
                .toLowerCase()
                .replace(/(^| )(\w)/g, (x) ->
                  return x.toUpperCase())
              persona: {
                email: user.persona.email
              }
            }

        if _.isEmpty(id)
          console.log 'Unable to claim wiki', req.hostname, ' no valid id provided'
          res.sendStatus(500)
        else
          setOwner id, (err) ->
            if err
              console.log 'Failed to claim wiki ', req.hostname, ' for ', id
              res.sendStatus(500)
            updateOwner getOwner()
            res.json({
              ownerName: id.name
              })


    app.get '/logout', (req, res) ->
      console.log 'Logout...'
      req.logout()
      res.send("OK")

  security
