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

  admin = argv.admin

  statusDir = argv.status

  console.log "statusDir: ", statusDir

  idFile = path.join(statusDir, "owner.json")

  personaIDFile = argv.id
  usingPersona = false

  ids = {}

  schemes = {}

  # Mozilla Persona service closes on
  personaEnd = new Date('2016-11-30')


  #### Public stuff ####

  # Attempt to figure out if the wiki is claimed or not,
  # if it is return the owner.

  security.retrieveOwner = (cb) ->
    fs.exists personaIDFile, (exists) ->
      if exists
        fs.readFile(personaIDFile, (err, data) ->
          if err then return cb err
          owner += data
          usingPersona = true
          cb())
      else
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
    if usingPersona
      if ~owner.indexOf '@'
        ownerName = owner.substr(0, owner.indexOf('@'))
      else
        ownerName = owner
      ownerName = ownerName.split('.').join(' ')
    else
      if !owner.name?
        ownerName = ''
      else
        ownerName = owner.name
    ownerName

  security.setOwner = setOwner = (id, cb) ->
    fs.exists idFile, (exists) ->
      if !exists
        fs.writeFile(idFile, id, (err) ->
          if err then return cb err
          console.log "Claiming wiki #{wikiName} for #{id}"
          owner = id
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
    if usingPersona
      # not added legacy support yet, so...
      return false
    else if owner is ''
      # site not claimed?
      return true
    else
      authorized = false
      try
        authorized = switch req.session.passport.user.provider
          when "twitter"
            if owner.twitter.id is req.session.passport.user.id
              true
      return authorized


  security.isAdmin = (req) ->
    if usingPersona
      # not added legacy support yet, so...
      return false
    else
      admin = false
      try
        admin = switch req.session.passport.user.provider
          when "twitter"
            if admin is req.session.passport.user.id
              true
      return admin

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


    ###
    if argv.github_clientID? and argv.github_clientSecret?
      github = {}
      github['clientID'] = argv.github_clientID
      github['clientSecret'] = argv.github_clientSecret
      ids['github'] = github

      GithubStrategy = require('passport-github').Strategy

      passport.use(new GithubStrategy({
        clientID: ids['github'].clientID
        clientSecret: ids['github'].clientSecret
        # this is not going to work - callback must equal that specified won github
        # when the application was setup - it can't be dynamic....
        callbackURL: 'http://localhost:3000/auth/github/callback'
        }, (accessToken, refreshToken, profile, cb) ->
          User.findOrCreate({githubID: profile.id}, (err, user) ->
            return cb(err, user))))
    ###

    if argv.twitter_consumerKey? and argv.twitter_consumerSecret?
      schemes['twitter'] = true
      twitter = {}
      twitter['consumerKey'] = argv.twitter_consumerKey
      twitter['consumerSecret'] = argv.twitter_consumerSecret
      ids['twitter'] = twitter

      TwitterStrategy = require('passport-twitter').Strategy

      passport.use(new TwitterStrategy({
        consumerKey: ids['twitter'].consumerKey
        consumerSecret: ids['twitter'].consumerSecret
        callbackURL: '/auth/twitter/callback'
        }, (accessToken, refreshToken, profile, cb) ->
          user = {
            "provider": 'twitter',
            "id": profile.id,
            "username": profile.username,
            "displayName": profile.displayName
          }
          cb(null, user)))

    ###
    if argv.google_clientID? and argv.google_clientSecret?
      google = {}
      google['clientID'] = argv.google_clientID
      google['clientSecret'] = argv.google_clientSecret
      ids['google'] = google

      GoogleStrategy = require('passport-google-oauth20').Strategy

      passport.use(new GoogleStrategy({
        clientID: ids['google'].clientID
        clientSecret: ids['google'].clientSecret
        callbackURL: 'http://localhost:3000/auth/google/callback'
        }, (accessToken, refreshToken, profile, cb) ->
          cb(null, profile)))
    ###

    app.use(passport.initialize())
    app.use(passport.session())

    ### Github
    app.get('/auth/github', passport.authenticate('github'), (req, res) -> )
    app.get('/auth/github/callback',
      passport.authenticate('github', { failureRedirect: '/'}), (req, res) ->
        # do what ever happens on login
      )
    ###

    # Twitter
    app.get('/auth/twitter', passport.authenticate('twitter'), (req, res) -> )
    app.get('/auth/twitter/callback',
      passport.authenticate('twitter', { successRedirect: '/auth/loginDone', failureRedirect: '/auth/loginDialog'}))




    ### Google
    app.get('/auth/google', passport.authenticate('google', { scope: [
      'https://www.googleapis.com/auth/plus.profile.emails.read'
      ]}))
    app.get('/auth/google/callback',
      passport.authenticate('google', {failureRedirect: '/'}), (req, res) ->
        console.log 'google logged in!!!!'
        res.redirect('/view/welcome-visitors'))
    ###

    app.get '/auth/loginDialog', (req, res) ->

      info = {
        wikiName: req.hostname
        wikiHostName: "a federated wiki site"
        title: if owner
          "Wiki Site Owner Sign-on"
        else
          "Sign-on to claim Wiki site"
        schemes: "<a href='/auth/twitter'><i class='fa fa-twitter fa-2x fa-fw'></i></a>"
      }
      res.render(path.join(__dirname, '..', 'views', 'securityDialog.html'), info)

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
        id = switch user.provider
          when "twitter" then {
            name: user.displayName
            twitter: {
              id: user.id
              username: user.username
            }
          }
        console.log 'id: ', id
        setOwner JSON.stringify(id), (err) ->
          if err
            console.log 'Failed to claim wiki ', req.hostname, ' for ', id
            res.sendStatus(500)
          res.json({
            ownerName: id.name
            })



    app.get '/logout', (req, res) ->
      console.log 'Logout...'
      req.logout()
      res.send("OK")





  security
