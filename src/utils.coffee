Promise = require 'bluebird'

cp = require 'child_process'
fs = require 'fs-extra'

asar = require 'asar'
path = require 'path'
dot = require 'dot'

module.exports =

  exec: (cmd, args, options) ->
    new Promise (resolve, reject) ->
      cp.execFile cmd, args, options, (error, stdout, stderr) ->
        if error
          reject error
        else
          resolve stdout

  getPackageJson: (appDirectory) ->
    try
      JSON.parse asar.extractFile path.resolve(appDirectory, 'resources', 'app.asar'), 'package.json'
    catch error
      try
        require path.resolve appDirectory, 'resources', 'app', 'package.json'
      catch error
        throw new Error 'Neither the resources/app folder nor the resources/app.asar package were found.'

  getNuSpec: (opts) ->
    template = fs.readFileSync path.resolve __dirname, '..', 'resources', 'template.nuspec'
    template = dot.template template.toString()
    template opts

  escape: (str) ->
    str.replace /&/g, '&amp;'
      .replace /</g, '&lt;'
      .replace />/g, '&gt;'
      .replace /"/g, '&quot;'
      .replace /'/g, '&apos;'
      .replace /@/g, '&#64;'

  # NuGet allows pre-release version-numbers, but the pre-release name cannot
  # have a dot in it. See the docs:
  # https://docs.nuget.org/create/versioning#user-content-prerelease-versions
  convertVersion: (version) ->
    parts = version.split('-')
    mainVersion = parts.shift()
    if parts.length > 0
      [mainVersion, parts.join('-').replace(/\./g, '')].join('-')
    else
      mainVersion
