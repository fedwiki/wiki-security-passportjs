// persona identity to owner.json file converter
//
// run this in the wiki home directory - typically ~/.wiki
// the persona.identity files are retained, but will no longer be used.

const _ = require('lodash')
const glob = require('glob')
const fs = require('fs')
const path = require('path')

const wikiDir = path.resolve('/Users/Paul/.wiki')
console.log('wikiDir: ', wikiDir)

glob('**/persona.identity', {cwd: wikiDir}, (err, files) => {
  _.forEach(files,  function(file) {
    console.log('found... ', file)
    var ownerFile = path.join(wikiDir, path.dirname(file),'owner.json')
    var owner = {}
    fs.readFile(path.join(wikiDir, file), 'utf8', (err, ownerEmail) => {
      ownerEmail = ownerEmail.replace(/\r?\n|\r/, '')
      var ownerName = ownerEmail.substr(0, ownerEmail.indexOf('@'))
      ownerName = ownerName.split('.').join(' ').toLowerCase().replace(/(^| )(\w)/g, function(x) {return x.toUpperCase()})
      owner.name = ownerName
      owner.persona = { email: ownerEmail }
      console.log('saving ', owner, ' to ', ownerFile)
      fs.writeFile(ownerFile, JSON.stringify(owner), (err) => {
        if (err) throw err
      })
    })
  })
})
