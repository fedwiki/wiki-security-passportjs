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

dialogCallback = (msg) ->
  alert('Dialog callback: ' + msg)

update_footer = (owner, authUser) ->
  # we update the owner and the login state in the footer, and
  # populate the security dialog

  if owner
    $('footer > #site-owner').html("Site Owned by: <span id='site-owner' style='text-transform:capitalize;'>#{owner}</span>")

  $('footer > #security').empty()

  if authUser is true
    $('footer > #security').append "<a href='#' id='show-security-dialog' class='footer-item' title='Sign-out'><i class='fa fa-unlock fa-lg fa-fw'></i></a>"
  else
    $('footer > #security').append "<a href='#' id='show-security-dialog' class='footer-item' title='Sign-on'><i class='fa fa-lock fa-lg fa-fw'></i></a>"

  $('footer > #security')
    .delegate '#show-security-dialog', 'click', (e) ->
      e.preventDefault()
      securityDialog = window.open("/auth/loginDialog", "_blank", "menubar=no, location=no, chrome=yes, centerscreen")
      
      securityDialog.window.focus()




setup = (user) ->

  if (!$("link[href='https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css']").length)
    $('<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css">').appendTo("head")
  if (!$("link[href='/security/style.css']").length)
    $('<link rel="stylesheet" href="/security/style.css">').appendTo("head")



  update_footer owner, authUser

window.plugins.security = {setup}
