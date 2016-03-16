fs = require 'fs'
assert = require 'assert'

Promise = require 'bluebird'
electronInstaller = require '../dist'

describe 'create-windows-installer task', ->
  beforeEach ->
    updateExePath = './fixtures/app/Update.exe'
    fs.unlinkSync updateExePath if fs.existsSync updateExePath

  it 'creates a nuget package and installer', (done) ->
    electronInstaller
      appDirectory: './test/fixtures/app'
      outputDirectory: './build'
      description: 'Default app.'
      authors: 'GitHub Inc.'
      version: '1.0.0'
      iconUrl: 'https://raw.githubusercontent.com/Aluxian/electron-windows-installer/master/resources/icon.png'
    .then new Promise (resolve, reject) ->
      interval = setInterval ->
        if fs.existsSync('./build/ElectronSetup.exe')
          clearInterval interval
          assert.equal true, fs.existsSync('./test/fixtures/app/Update.exe')
          assert.equal true, fs.existsSync('./build/electron-1.0.0-full.nupkg')
          if process.platform is 'win32'
            assert.equal true, fs.existsSync('./build/ElectronSetup.msi')
          assert.equal true, fs.existsSync('./build/ElectronSetup.exe')
          resolve()
      , 5 * 1000
    .then () -> done()
    .catch done
