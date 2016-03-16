###
 * Federated Wiki : Security Plugin : Social
 *
 * Copyright Ward Cunningham and other contributors
 * Licensed under the MIT license.
 * https://github.com/fedwiki/wiki-security-social/blob/master/LICENSE.txt
###
# **Persona : security.coffee**
# Module for Persona (BrowserID) based security.
#
# This module is based on the previously built-in security.

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
  User = {}

  admin = argv.admin

  statusDir = argv.statusDir

  idFile = argv.id

  ids = {}

  schemes = {}


  #### Public stuff ####

  # Attempt to figure out if the wiki is claimed or not,
  # if it is return the owner.

  security.retrieveOwner = (cb) ->
    fs.exists idFile, (exists) ->
      if exists
        fs.readFile(idFile, (err, data) ->
          if err then return cb err
          owner += data
          cb())
      else
        owner = ''
        cb()

  security.getOwner = getOwner = ->
    if ~owner.indexOf '@'
      ownerName = owner.substr(0, owner.indexOf('@'))
    else
      ownerName = owner
    ownerName = ownerName.split('.').join(' ')
    ownerName

  security.setOwner = setOwner = (id, cb) ->
    fs.exists idfile, (exists) ->
      if !exists
        fs.writeFile(idFile, id, (err) ->
          if err then return cb err
          console.log "Claining site for #{id}"
          owner = # IDEA:
          cb())
      else
        cb()

  security.getUser = (req) ->
    if req.session.email
      return req.session.email
    else
      return ''

  security.isAuthorized = (req) ->
    if [req.session.email, ''].indexOf(owner) > -1
      return true
    else
      return false

  security.isAdmin = (req) ->
    if !(req.session.email? or admin?)
      return false
    if req.session.email is admin
      return true
    else
      return false

  security.login = (updateOwner) ->











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
          console.log "Profile: ", profile
          cb(null, profile)))

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
          console.log "Profile: ", profile
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
      passport.authenticate('twitter', {failureRedirect: '/'}), (req, res) ->
        console.log 'twitter logged in!!!!'
        res.send('twitter logged in'))


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
        title: if owner
          "Wiki Site Owner Sign-on"
        else
          "Sign-on to claim Wiki site"
      schemes: "<a href='/auth/twitter'><i class='fa fa-twitter'></i></a>"

      }
      res.render(path.join(__dirname, '..', 'views', 'securityDialog.html'), info)




  security
