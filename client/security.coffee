###
 * Federated Wiki : Social Security Plugin
 *
 * Licensed under the MIT license.
 * https://github.com/fedwiki/wiki-security-social/blob/master/LICENSE.txt
###

###
1. Display login button - if there is no authenticated user
2. Display logout button - if the user is authenticated

3. When user authenticated, claim site if unclaimed - and repaint footer.

###

settings = {}

# Mozilla Persona service closes on
personaEnd = new Date('2016-11-30')

claim_wiki = () ->
  # we want to initiate a claim on a wiki
  #
  # this is don't after login, so that login can be performed at wiki TLD
  if !isClaimed
    # only try and claim if we think site is unclaimed
    myInit = {
      method: 'GET'
      cache: 'no-cache'
      mode: 'same-origin'
      credentials: 'include'
    }
    fetch '/auth/claim-wiki', myInit
    .then (response) ->
      if response.ok
        response.json().then (json) ->
          ownerName = json.ownerName
          window.isClaimed = true
          update_footer ownerName, true
      else
        console.log 'Attempt to claim site failed', response


update_footer = (ownerName, isAuthenticated) ->
  # we update the owner and the login state in the footer, and
  # populate the security dialog

  if ownerName
    $('footer > #site-owner').html("Site Owned by: <span id='site-owner' style='text-transform:capitalize;'>#{ownerName}</span>")

  $('footer > #security').empty()

  if isAuthenticated
    $('footer > #security').append "<a href='#' id='logout' class='footer-item' title='Sign-out'><i class='fa fa-unlock fa-lg fa-fw'></i></a>"
    $('footer > #security > #logout').click (e) ->
      e.preventDefault()
      myInit = {
        method: 'GET'
        cache: 'no-cache'
        mode: 'same-origin'
        credentials: 'include'
      }
      fetch '/logout', myInit
      .then (response) ->
        if response.ok
          isAuthenticated = false
          isOwner = false
          user = ''
          document.cookie = "state=loggedOut" + ";domain=." + settings.cookieDomain + "; path=/; max-age=60;"
          update_footer ownerName, isAuthenticated
        else
          console.log 'logout failed: ', response
    # These probably should move into a menu, but this is far easier to begin with
    if !isClaimed
      $('footer > #security').append "<a href='#' id='claim' class='foot-item' title='Claim this Wiki'><i class='fa fa-key fa-lg fa-fw'></i></a>"
      $('footer > #security > #claim').click (e) ->
        e.preventDefault()
        claim_wiki()
    else
      # only offer to add alternative id if using persona - at least initially.
      if settings.usingPersona
        $('footer > #security').append "<a href='#' id='addAltAuth' class='foot-item' title='Add Alternative Credentials'><i class='fa fa-user-plus fa-lg fa-fw'></i></a>"
        $('footer > #security > #addAltAuth').click (e) ->
          e.preventDefault

          w = WinChan.open({
            url: settings.dialogAddAltURL
            relay_url: settings.relayURL
            window_features: "menubar=0, location=0, resizable=0, scrollbars=0, status=0, dialog=1, width=700, height=375"
            params: {}
            }, (err, r) ->
              if err
                console.log err
              else
                # add call to add alternative to owner here
                console.log 'send request to add owner identity'
                myInit = {
                  method: 'GET'
                  cache: 'no-cache'
                  mode: 'same-origin'
                  credentials: 'include'
                }
                fetch '/auth/addAltAuth', myInit
                .then (response) ->
                  if response.ok
                    console.log 'Alternative Identity added', response
                    settings.usingPersona = false
                    update_footer ownerName, isAuthenticated  
                  else
                    console.log 'Attempt to claim site failed', response
                )
  else
    if !isClaimed
      signonTitle = 'Claim this Wiki'
    else
      signonTitle = 'Wiki Owner Sign-on'
    $('footer > #security').append "<a href='#' id='show-security-dialog' class='footer-item' title='#{signonTitle}'><i class='fa fa-lock fa-lg fa-fw'></i></a>"
    $('footer > #security > #show-security-dialog').click (e) ->
      e.preventDefault()

      w = WinChan.open({
        url: settings.dialogURL
        relay_url: settings.relayURL
        window_features: "menubar=0, location=0, resizable=0, scrollbars=0, status=0, dialog=1, width=700, height=375"
        params: {}
        }, (err, r) ->
          if err
            console.log err
          else if !isClaimed
            claim_wiki()
          else
            update_footer ownerName, true)



setup = (user) ->

  # we will replace font-awesome with a small number of svg icons at a later date...
  if (!$("link[href='https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css']").length)
    $('<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css">').appendTo("head")

  # signon could happen in a different window, so listen for cookie changes
  lastCookie = document.cookie
  window.setInterval ->
    currentCookie = document.cookie
    if currentCookie != lastCookie
      console.log "Cookie changed"
      unless document.cookie.match('(?:^|;)\\s?state=(.*?)(?:;|$)') is null
        try
          switch document.cookie.match('(?:^|;)\\s?state=(.*?)(?:;|$)')[1]
            when 'loggedIn' then isAuthenticated = true
            when 'loggedOut' then isAuthenticated = false
          update_footer ownerName, isAuthenticated
      lastCookie = currentCookie
  , 100

  wiki.getScript '/security/modernizr-custom.js', () ->
    console.log 'modernizr loaded'
    unless Modernizr.promises
      require('es6-promise').polyfill()

    unless Modernizr.fetch
      require('whatwg-fetch')

    wiki.getScript '/security/winchan.js'
    if (!$("link[href='/security/style.css']").length)
      $('<link rel="stylesheet" href="/security/style.css">').appendTo("head")
    myInit = {
      method: 'GET'
      cache: 'no-cache'
      mode: 'same-origin'
    }
    fetch '/auth/client-settings.json', myInit
    .then (response) ->
      if response.ok
        response.json().then (json) ->
          settings = json
          if settings.wikiHost
            dialogHost = settings.wikiHost
          else
            dialogHost = window.location.hostname
          settings.cookieDomain = dialogHost
          if settings.useHttps
            dialogProtocol = 'https:'
          else
            dialogProtocol = window.location.protocol
            if window.location.port
              dialogHost = dialogHost + ':' + window.location.port
          if settings.usingPersona
            settings.dialogURL = dialogProtocol + '//' + dialogHost + '/auth/personaLogin'
          else
            settings.dialogURL = dialogProtocol + '//' + dialogHost + '/auth/loginDialog'
          settings.relayURL = dialogProtocol + '//' + dialogHost + '/auth/relay.html'
          settings.dialogAddAltURL = dialogProtocol + '//' + dialogHost + '/auth/addAuthDialog'


          update_footer ownerName, isAuthenticated
      else
        console.log 'Unable to fetch client settings: ', response

window.plugins.security = {setup, claim_wiki, update_footer}
