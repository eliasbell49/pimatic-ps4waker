# #Plugin template

# This is an plugin template and mini tutorial for creating pimatic plugins. It will explain the 
# basics of how the plugin system works and how a plugin should look like.

# ##The plugin code

# Your plugin must export a single function, that takes one argument and returns a instance of
# your plugin class. The parameter is an envirement object containing all pimatic related functions
# and classes. See the [startup.coffee](http://sweetpi.de/pimatic/docs/startup.html) for details.
module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  # Include you own depencies with nodes global require function:
  #  
  #     someThing = require 'someThing'
  #  

  Waker = require 'ps4-waker'

  # ###MyPlugin class
  # Create a class that extends the Plugin class and implements the following functions:
  class Ps4WakerPlugin extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 
    #     
    # 
    init: (app, @framework, @config) =>
      env.logger.info("Hello World")

      deviceConfigDef = require("./ps4-device-config-schema")

      @framework.deviceManager.registerDeviceClass("Ps4PowerSwitch", {
        configDef: deviceConfigDef.Ps4PowerSwitch,
        createCallback: (config) => new Ps4PowerSwitch(config)
      })

  class Ps4PowerSwitch extends env.devices.PowerSwitch
    constructor: (@config) ->
      @name = @config.name
      @id = @config.id

      @waker = new Waker(@config.credentialsPath, {
        errorIfAwake: false
      })

      super()

    destroy: () ->
      delete @waker
      super()

    changeStateTo: (state) ->
      self = this
      return new Promise((resolve, reject) ->
        self.waker.readCredentials((err, creds) ->
          return if err then reject(err)

          if state
            dev = if self.config.ipAddress then { address: self.config.ipAddress } else undefined
            self.waker.wake({ timeout: 45000 }, dev, (err) ->
              return if err then reject(err)
              env.logger.debug('PS4: Wake-up requested')
              self._setState(state)
              resolve()
            )
          else
            Waker.Detector.findAny(undefined, (err, device, rinfo) ->
              return if err then reject(err)
              Waker.Socket({
                accountId: creds['user-credential'],
                host: rinfo.address
              }).on('ready', () ->
                @requestStandby((err) ->
                  return if err then reject(err)
                  env.logger.debug('PS4: Standby requested')
                  self._setState(state)
                  resolve()
                )
              ).on('error', (err) ->
                return if err then reject(err)
                env.logger.error('Unable to connect to PS4 at', rinfo.address, err)
              )
            )
        )
      )

    getState: () ->
      self = this
      return new Promise((resolve, reject) ->
        self.waker.readCredentials((err, creds) ->
          return if err then reject(err)
          Waker.Detector.findAny(undefined, (err, device, rinfo) ->
            return if err then reject(err)

            env.logger.debug('PS4 state: ' + device.status)
            resolve(device.status and device.status.toLowerCase() isnt 'standby')
          )
        )
      )


  # ###Finally
  # Create a instance of my plugin
  myPlugin = new Ps4WakerPlugin
  # and return it to the framework.
  return myPlugin