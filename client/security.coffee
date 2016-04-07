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
          update_footer ownerName, true, true
          console.log 'owner: ', json.ownerName, ' : ', ownerName
      else
        console.log 'Attempt to claim site failed', response


update_footer = (ownerName, isAuthenticated, isOwner) ->
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
          update_footer ownerName, isAuthenticated, isOwner
        else
          console.log 'logout failed: ', response
  else
    if !isClaimed
      signonTitle = 'Claim this Wiki'
    else
      signonTitle = 'Sign-on'
    $('footer > #security').append "<a href='#' id='show-security-dialog' class='footer-item' title='#{signonTitle}'><i class='fa fa-lock fa-lg fa-fw'></i></a>"
    $('footer > #security > #show-security-dialog').click (e) ->
      e.preventDefault()
      securityDialog = window.open(
        "/auth/loginDialog",
        "_blank",
        "width=700, height=375, menubar=no, location=no, chrome=yes, centerscreen")
      securityDialog.window.focus()



setup = (user) ->

  if (!$("link[href='https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css']").length)
    $('<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css">').appendTo("head")
  if (!$("link[href='/security/style.css']").length)
    $('<link rel="stylesheet" href="/security/style.css">').appendTo("head")

  update_footer ownerName, isAuthenticated, isOwner

window.plugins.security = {setup, claim_wiki, update_footer}
