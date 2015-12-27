Promise = require 'bluebird'
fs = require 'fs-extra'
path = require 'path'
temp = require 'temp'

utils = require './utils'

class InstallerFactory
  constructor: (opts) ->
    unless opts.appDirectory
      throw new Error 'Please provide the "appDirectory" config parameter.'

    appMetadata = utils.getPackageJson opts.appDirectory
    @appDirectory = opts.appDirectory
    @outputDirectory = path.resolve(opts.outputDirectory || 'installer')
    @loadingGif = if opts.loadingGif then path.resolve opts.loadingGif else path.resolve __dirname, '..', 'resources', 'install-spinner.gif'
    @authors = opts.authors || appMetadata.author || ''
    @owners = opts.owners || @authors
    @copyright = opts.copyright || "Copyright © #{new Date().getFullYear()} #{@authors || @owners}"
    @name = appMetadata.name
    @productName = appMetadata.productName || @name
    @exe = opts.exe || @productName + '.exe'
    @setupExe = opts.setupExe || @productName + 'Setup.exe'
    @setupMsi = opts.setupMsi || @productName + 'Setup.msi'
    @iconUrl = opts.iconUrl || ''
    @description = opts.description || appMetadata.description || ''
    @version = utils.convertVersion(opts.version || appMetadata.version || '')
    @title = opts.title || @productName || @name
    @certificateFile = opts.certificateFile
    @certificatePassword = opts.certificatePassword
    @signWithParams = opts.signWithParams
    @setupIcon = opts.setupIcon
    @remoteReleases = opts.remoteReleases && opts.remoteReleases.replace('.git', '')
    @noMsi = opts.noMsi
    @arch = opts.arch || process.arch

    @name = utils.escapeEntities @name
    @title = utils.escapeEntities @title
    @version = utils.escapeEntities @version
    @authors = utils.escapeEntities @authors
    @owners = utils.escapeEntities @owners
    @iconUrl = utils.escapeEntities @iconUrl
    @description = utils.escapeEntities @description
    @copyright = utils.escapeEntities @copyright
    @exe = utils.escapeEntities @exe

    unless @authors
      throw new Error 'Authors required: set "authors" in options or "author" in package.json'

  syncReleases: () =>
    if @remoteReleases
      cmd = path.resolve __dirname, '..', 'vendor', 'SyncReleases.exe'
      args = ['-u', @remoteReleases, '-r', @outputDirectory]
      utils.exec cmd, args
    else
      Promise.resolve()

  packRelease: () =>
    nupkgPath = path.join @nugetOutput, "#{@name}.#{@version}.nupkg"
    cmd = path.resolve __dirname, '..', 'vendor', 'Squirrel.exe'
    args = [
      '--releasify'
      nupkgPath
      '--releaseDir'
      @outputDirectory
      '--loadingGif'
      @loadingGif
    ]

    if @signWithParams
      args.push '--signWithParams'
      args.push '\"' + @signWithParams + '\"'
    else if @certificateFile and @certificatePassword
      args.push '--signWithParams'
      args.push "/a\ /f\ #{@certificateFile}\ /p\ #{@certificatePassword}"

    if @noMsi
      args.push '--no-msi'

    if @setupIcon
      args.push '--setupIcon'
      args.push path.resolve @setupIcon

    utils.exec cmd, args

  renameSetupFile: () =>
    oldSetupPath = path.join @outputDirectory, 'Setup.exe'
    newSetupPath = path.join @outputDirectory, @setupExe
    oldSetupMsiPath = path.join @outputDirectory, 'Setup.msi'
    newSetupMsiPath = path.join @outputDirectory, @setupMsi
    fs.renameSync oldSetupPath, newSetupPath
    if fs.existsSync oldSetupMsiPath
      fs.renameSync oldSetupMsiPath, newSetupMsiPath
    Promise.resolve()

  createInstaller: () ->
    # Start tracking temp dirs to be cleaned
    temp.track()

    # Generate nuget
    @nugetOutput = temp.mkdirSync 'squirrel-installer-'
    targetNuspecPath = path.join @nugetOutput, @name + '.nuspec'
    fs.writeFileSync targetNuspecPath, utils.getNuSpec @

    cmd = path.resolve __dirname, '..', 'vendor', 'nuget.exe'
    args = [
      'pack'
      targetNuspecPath
      '-BasePath'
      path.resolve @appDirectory
      '-OutputDirectory'
      @nugetOutput
      '-NoDefaultExcludes'
    ]

    utils.exec cmd, args
      .then @syncReleases
      .then @packRelease
      .then @renameSetupFile

module.exports = (opts) ->
  try
    new InstallerFactory(opts).createInstaller()
  catch error
    Promise.reject error
