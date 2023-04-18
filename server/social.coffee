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

  #### Public stuff ####

  # Attempt to figure out if the wiki is claimed or not,
  # if it is return the owner.

  security.retrieveOwner = (cb) ->
    fs.exists idFile, (exists) ->
      if exists
        fs.readFile(idFile, (err, data) ->
          if err then return cb err
          owner = JSON.parse(data)
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
          console.log "Claiming wiki #{wikiName} for #{id.name}"
          owner = id
          ownerName = owner.name
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
        console.log 'idProvider: ', idProvider
        switch idProvider
          when 'github', 'google', 'twitter', 'oauth2'
            if _.isEqual(owner[idProvider].id, req.session.passport.user[idProvider].id)
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
      when "github", "google", "twitter", 'oauth2'
        if _.isEqual(admin[idProvider], req.session.passport.user[idProvider].id)
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

    # OAuth Strategy
    if argv.oauth2_clientID? and argv.oauth2_clientSecret?
      ids.push('oauth2')
      OAuth2Strategy = require('passport-oauth2').Strategy

      oauth2StrategyName = callbackHost + 'OAuth'

      if argv.oauth2_UserInfoURL?
        OAuth2Strategy::userProfile = (accesstoken, done) -> 
          console.log "hello"
          console.log accesstoken
          @_oauth2._request "GET", argv.oauth2_UserInfoURL, null, null, accesstoken, (err, data) ->
            if err
              return done err 
            try
              data = JSON.parse data 
            catch e
              return done e
            done(null, data)

      passport.use(oauth2StrategyName, new OAuth2Strategy({
        clientID: argv.oauth2_clientID
        clientSecret: argv.oauth2_clientSecret
        authorizationURL: argv.oauth2_AuthorizationURL
        tokenURL: argv.oauth2_TokenURL,
        # not all providers have a way of specifying the callback URL
        callbackURL: callbackProtocol + '//' + callbackHost + '/auth/oauth2/callback',
        userInfoURL: argv.oauth2_UserInfoURL
        }, (accessToken, refreshToken, params, profile, cb) ->

          extractUserInfo = (uiParam, uiDef) ->
            uiPath = ''
            if typeof uiParam == 'undefined' then (uiPath = uiDef) else (uiPath = uiParam)
            console.log('extractUI', uiParam, uiDef, uiPath)
            sParts = uiPath.split('.')
            sFrom = sParts.shift()
            switch sFrom
              when "params"
                obj = params
              when "profile"
                obj = profile
              else
                console.error('*** source of user info not recognised', uiPath)
                obj = {}
            
            while (sParts.length)
              obj = obj[sParts.shift()]
            return obj

          console.log("accessToken", accessToken)
          console.log("refreshToken", refreshToken)
          console.log("params", params)
          console.log("profile", profile)
          if argv.oauth2_UsernameField?
            username_query = argv.oauth2_UsernameField 
          else 
            username_query = 'params.user_id'

          try
            user.oauth2 = {
              id: extractUserInfo(argv.oauth2_IdField, 'params.user_id')
              username: extractUserInfo(argv.oauth2_UsernameField, 'params.user_id')
              displayName: extractUserInfo(argv.oauth2_DisplayNameField, 'params.user_id')
            }
          catch e
            console.error('*** Error extracting user info:', e)
          console.log user.oauth2
          cb(null, user)))

    # Github Strategy
    if argv.github_clientID? and argv.github_clientSecret?
      ids.push('github')
      GithubStrategy = require('passport-github2').Strategy

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
      TwitterStrategy = require('@passport-js/passport-twitter').Strategy

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

    app.use(passport.initialize())
    app.use(passport.session())

    # OAuth2
    app.get('/auth/oauth2', passport.authenticate(oauth2StrategyName), (req, res) -> )
    app.get('/auth/oauth2/callback',
      passport.authenticate(oauth2StrategyName, { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))

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
      'profile', 'email'
      ]}))
    # see https://developers.google.com/identity/protocols/OpenIDConnect#authenticationuriparameters for details of prompt...
    app.get('/auth/google/callback',
      passport.authenticate(googleStrategyName, { prompt: 'select_account', successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))


    app.get '/auth/client-settings.json', (req, res) ->
      # the client needs some information to configure itself
      settings = {
        useHttps: useHttps
      }
      if wikiHost
        settings.wikiHost = wikiHost
      if isAuthorized(req) and owner isnt ''
        settings.isOwner = true
      else
        settings.isOwner = false
      res.json settings

    app.get '/auth/loginDialog', (req, res) ->
      cookies = req.cookies
      schemeButtons = []
      _(ids).forEach (scheme) ->
        switch scheme
          when "oauth2" then schemeButtons.push({button: "<a href='/auth/oauth2' class='scheme-button oauth2-button'><span>OAuth2</span></a>"})
          when "twitter" then schemeButtons.push({button: "<a href='/auth/twitter' class='scheme-button twitter-button'><span>Twitter</span></a>"})
          when "github" then schemeButtons.push({button: "<a href='/auth/github' class='scheme-button github-button'><span>Github</span></a>"})
          when "google"
            schemeButtons.push({button: "<a href='#' id='google' class='scheme-button google-button'><span>Google</span></a>
              <script>
                googleButton = document.getElementById('google');
                googleButton.onclick = function(event) {
                  window.resizeBy(0, +300);
                  window.location = '/auth/google';
                }
              </script>"})


      info = {
        wikiName: cookies['wikiName']
        wikiHostName: if wikiHost
          "part of " + req.hostname + " wiki farm"
        else
          "a federated wiki site"
        title: "Federated Wiki: Site Owner Sign-on"
        loginText: "Sign in to"
        schemes: schemeButtons
      }
      res.render(path.join(__dirname, '..', 'views', 'securityDialog.html'), info)

    app.get '/auth/loginDone', (req, res) ->
      cookies = req.cookies

      info = {
        wikiName: cookies['wikiName']
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


    # if configured, enforce restricted access to json
    # see http://ward.asia.wiki.org/login-to-view.html

    if argv.restricted?

      allowedToView = (req) ->
        allowed = []
        if argv.allowed_domains?
          if Array.isArray(argv.allowed_domains)
            allowed = argv.allowed_domains
          else
            # accommodate copy bug to be fixed soon
            # https://github.com/fedwiki/wiki/blob/4c6eee69e78c1ba3f3fc8d61f4450f70afb78f10/farm.coffee#L98-L103
            for k, v of argv.allowed_domains
              allowed.push v
        # emails = [ { value: 'ward.cunningham@gmail.com', type: 'account' } ]
        emails = req.session?.passport?.user?.google?.emails
        return false unless emails
        for entry in emails
          have = entry.value.split('@')[1]
          for want in allowed
            return true if want == have
        false

      app.all '*', (req, res, next) ->
        # todo: think about assets??
        return next() unless /\.(json|html)$/.test req.url

        # prepare to examine remote server's forwarded session
        res.header 'Access-Control-Allow-Origin', req.get('Origin')||'*'
        res.header 'Access-Control-Allow-Credentials', 'true'
        return next() if isAuthorized(req) || allowedToView(req)
        return res.redirect("/view/#{m[1]}") if m = req.url.match /\/(.*)\.html/
        return res.json([]) if req.url == '/system/sitemap.json'

        # not happy, explain why these pages can't be viewed
        problem = "This is a restricted wiki requires users to login to view pages. You do not have to be the site owner but you do need to login with a participating email address."
        details = "[#{argv.details || 'http://ward.asia.wiki.org/login-to-view.html'} details]"
        res.status(200).json(
          {
            "title": "Login Required",
            "story": [
              {
                "type": "paragraph",
                "id": "55d44b367ed64875",
                "text": "#{problem} #{details}"
              }
            ]
          }
        )


    app.get '/auth/addAuthDialog', (req, res) ->
      # only makes sense to add alternative authentication scheme if
      # this the user is authenticated
      user = getUser(req)
      if user
        cookies = req.cookies


        currentSchemes = _.keys(user)
        altSchemes = _.difference(ids, currentSchemes)

        schemeButtons = []
        _(altSchemes).forEach (scheme) ->
          switch scheme
            when "twitter" then schemeButtons.push({button: "<a href='/auth/twitter' class='scheme-button twitter-button'><span>Twitter</span></a>"})
            when "github" then schemeButtons.push({button: "<a href='/auth/github' class='scheme-button github-button'><span>Github</span></a>"})
            when "google" then schemeButtons.push({button: "<a href='/auth/google' class='scheme-button google-button'><span>Google</span></a>"})

        info = {
          wikiName: cookies['wikiName']
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

    app.get '/auth/claim-wiki', (req, res) ->
      if owner
        console.log 'Claim Request Ignored: Wiki already has owner - ', wikiName
        res.sendStatus(403)
      else
        user = req.session.passport.user
        idProviders = _.keys(user)

        id = {}
        idProviders.forEach (idProvider) ->
          id = switch idProvider
            when "oauth2" then {
              name: user.oauth2.displayName
              oauth2: {
                id: user.oauth2.id
                username: user.oauth2.username
              }
            }
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
              name: user.google.displayName || (user.google.emails[0]?.value?.split('@')[0]) || 'unknown'
              google: {
                id: user.google.id
                emails: user.google.emails
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

    app.get '/auth/diag', (req, res) ->
      # some diagnostic feedback to the user, for when something strange happens
      user = 'User is unknown'
      try
        user = req.session.passport.user
      date = new Date().toString()
      wikiName = new URL(argv.url).hostname
      console.log 'SOCIAL *** ', date, ' *** ', wikiName, ' *** ', JSON.stringify(user)
      res.json date

    app.get '/logout', (req, res) ->
      console.log 'Logout...'
      req.logout()
      res.send("OK")

  security
