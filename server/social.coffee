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

_ = require('lodash')

passport = require 'passport'


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

  console.log "statusDir: ", statusDir

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


  #### Public stuff ####

  # Attempt to figure out if the wiki is claimed or not,
  # if it is return the owner.

  security.retrieveOwner = (cb) ->
    fs.exists idFile, (exists) ->
      if exists
        fs.readFile(idFile, (err, data) ->
          if err then return cb err
          owner = JSON.parse(data)
          console.log 'retrieveOwner owner: ', owner
          if _.has(owner, 'persona')
            usingPersona = true
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
          cb())
      else
        cb('Already Claimed')

  security.getUser = (req) ->
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
        idProvider = _.first(_.keys(_.pick(owner, _.keys(req.session.passport.user))))
        if _.isEqual(owner[idProvider], req.session.passport.user[idProvider])
          return true
        else
          return false
      catch error
        return false


  security.isAdmin = (req) ->
    try
      if admin
        idProvider = _.first(_.keys(_.pick(admin, _.keys(req.session.passport.user))))
        if _.isEqual(admin[idProvider], req.session.passport.user[idProvider])
          return true
        else
          return false
    catch error
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

      passport.use(new GithubStrategy({
        clientID: argv.github_clientID
        clientSecret: argv.github_clientSecret
        scope: 'user:emails'
        # callbackURL is optional, and if it exists must match that given in
        # the OAuth application settings - so we don't specify it.
        }, (accessToken, refreshToken, profile, cb) ->
          user = {
            provider: 'github',
            id: profile.id
            username: profile.username
            displayName: profile.displayName
            email: profile.emails[0].value
          }
          cb(null, user)))

    # Twitter Strategy
    if argv.twitter_consumerKey? and argv.twitter_consumerSecret?
      ids.push('twitter')
      TwitterStrategy = require('passport-twitter').Strategy

      passport.use(new TwitterStrategy({
        consumerKey: argv.twitter_consumerKey
        consumerSecret: argv.twitter_consumerSecret
        callbackURL: callbackProtocol + '//' + callbackHost + '/auth/twitter/callback'
        }, (accessToken, refreshToken, profile, cb) ->
          user = {
            provider: 'twitter',
            id: profile.id,
            username: profile.username,
            displayName: profile.displayName
          }
          cb(null, user)))

    # Google Strategy
    if argv.google_clientID? and argv.google_clientSecret?
      ids.push('google')
      GoogleStrategy = require('passport-google-oauth20').Strategy

      passport.use(new GoogleStrategy({
        clientID: argv.google_clientID
        clientSecret: argv.google_clientSecret
        callbackURL: callbackProtocol + '//' + callbackHost + '/auth/google/callback'
        }, (accessToken, refreshToken, profile, cb) ->
          user = {
            provider: "google"
            id: profile.id
            displayName: profile.displayName
            emails: profile.emails
          }
          cb(null, profile)))

    # Persona Strategy
    PersonaStrategy = require('persona-pass').Strategy

    passport.use(new PersonaStrategy({
      audience: callbackProtocol + '//' + callbackHost
      }, (email, cb) ->
        user = {
          persona: { email: email }
        }
        cb(null, user)))


    app.use(passport.initialize())
    app.use(passport.session())

    # Github
    app.get('/auth/github', passport.authenticate('github', {scope: 'user:email'}), (req, res) -> )
    app.get('/auth/github/callback',
      passport.authenticate('github', { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))

    # Twitter
    app.get('/auth/twitter', passport.authenticate('twitter'), (req, res) -> )
    app.get('/auth/twitter/callback',
      passport.authenticate('twitter', { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))

    # Google
    app.get('/auth/google', passport.authenticate('google', { scope: [
      'https://www.googleapis.com/auth/plus.profile.emails.read'
      ]}))
    app.get('/auth/google/callback',
      passport.authenticate('google', { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))

    # Persona
    app.post('/auth/browserid',
      passport.authenticate('persona', { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))


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
      console.log "logging into: ", url.parse(referer).hostname

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
      console.log "logging into: ", url.parse(referer).hostname

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
      info = {
        title: if owner
          "Wiki Site Owner Sign-on"
        else
          "Sign-on to claim Wiki site"
        owner: getOwner
        authMessage: "You are now logged in..."
      }
      res.render(path.join(__dirname, '..', 'views', 'done.html'), info)

    app.get '/auth/claim-wiki', (req, res) ->
      if owner
        console.log 'Claim Request Ignored: Wiki already has owner'
        res.sendStatus(403)
      else
        user = req.session.passport.user
        console.log "Claim: user = ", user
        id = switch user.provider
          when "twitter" then {
            name: user.displayName
            twitter: {
              id: user.id
              username: user.username
            }
          }
          when "github" then {
            name: user.displayName
            github: {
              id: user.id
              username: user.username
              email: user.email
            }
          }
          when "google" then {
            name: user.displayName
            google: {
              id: user.id
              emails: user.emails
            }
          }

        setOwner id, (err) ->
          if err
            console.log 'Failed to claim wiki ', req.hostname, ' for ', JSON.stringify(id)
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
