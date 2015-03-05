SyncSettings = require '../lib/sync-settings'
SpecHelper = require './spec-helpers'
run = SpecHelper.callAsync
fs = require 'fs'
# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "SyncSettings", ->

  describe "low-level", ->
    describe "::fileContent", ->
      it "returns non-empty string for not existing file", ->
        expect(SyncSettings.fileContent("/tmp/atom-sync-settings.tmp")).toBeTruthy()

      it "returns non-empty string for empty file", ->
        fs.writeFileSync "/tmp/atom-sync-settings.tmp", ""
        try
          expect(SyncSettings.fileContent("/tmp/atom-sync-settings.tmp")).toBeTruthy()
        finally
          fs.unlinkSync "/tmp/atom-sync-settings.tmp"

      it "returns content of existing file", ->
        text = "alabala portocala"
        fs.writeFileSync "/tmp/atom-sync-settings.tmp", text
        try
          expect(SyncSettings.fileContent("/tmp/atom-sync-settings.tmp")).toEqual text
        finally
          fs.unlinkSync "/tmp/atom-sync-settings.tmp"

  describe "high-level", ->
    TOKEN_CONFIG = 'sync-settings.personalAccessToken'
    GIST_ID_CONFIG = 'sync-settings.gistId'

    token = null
    gistId = null

    beforeEach ->
      @token = process.env.GITHUB_TOKEN || atom.config.get(TOKEN_CONFIG)
      atom.config.set(TOKEN_CONFIG, @token)

      run (cb) ->
        console.debug "Creating test gist..."
        gist =
          public: false
          description: "Test gist by Sync Settings for Atom https://github.com/Hackafe/atom-sync-settings"
          files:
            "README": {content: '# Generated by Sync Settings for Atom https://github.com/Hackafe/atom-sync-settings'}
        SyncSettings.createClient().gists.create(gist, cb)
      , (err, res) =>
        console.debug "Created test gist"
        expect(err).toBeNull()

        @gistId = res.id
        atom.config.set(GIST_ID_CONFIG, @gistId)


    afterEach ->
      run (cb) =>
        SyncSettings.createClient().gists.delete {id: @gistId}, cb
      , (err, res) ->
        expect(err).toBeNull()

    describe "::upload", ->
      it "uploads the settings", ->
        run (cb) ->
          SyncSettings.upload cb
        , ->
          run (cb) =>
            SyncSettings.createClient().gists.get({id: @gistId}, cb)
          , (err, res) ->
            expect(res.files['settings.json']).toBeDefined()

      it "uploads the installed packages list", ->
        run (cb) ->
          SyncSettings.upload cb
        , ->
          run (cb) =>
            SyncSettings.createClient().gists.get({id: @gistId}, cb)
          , (err, res) ->
            expect(res.files['packages.json']).toBeDefined()

      it "uploads the user keymap.cson file", ->
        run (cb) ->
          SyncSettings.upload cb
        , ->
          run (cb) =>
            SyncSettings.createClient().gists.get({id: @gistId}, cb)
          , (err, res) ->
            expect(res.files['keymap.cson']).toBeDefined()

      it "uploads the files defined in config.extraFiles", ->
        atom.config.set 'sync-settings.extraFiles', ['test.tmp', 'test2.tmp']
        run (cb) ->
          SyncSettings.upload cb
        , ->
          run (cb) =>
            SyncSettings.createClient().gists.get({id: @gistId}, cb)
          , (err, res) ->
            for file in atom.config.get 'sync-settings.extraFiles'
              expect(res.files[file]).toBeDefined()

    describe "::download", ->
      it "updates settings", ->
        atom.config.set "some-dummy", true
        run (cb) ->
          SyncSettings.upload cb
        , ->
          atom.config.set "some-dummy", false
          run (cb) ->
            SyncSettings.download cb
          , ->
            expect(atom.config.get "some-dummy").toBeTruthy()

      it "overrides keymap.cson", ->
        original = SyncSettings.fileContent atom.keymap.getUserKeymapPath()
        run (cb) ->
          SyncSettings.upload cb
        , ->
          fs.writeFileSync atom.keymap.getUserKeymapPath(), "#{original}\n# modified by sync setting spec"
          run (cb) ->
            SyncSettings.download cb
          , ->
            expect(SyncSettings.fileContent(atom.keymap.getUserKeymapPath())).toEqual original
            fs.writeFileSync atom.keymap.getUserKeymapPath(), original

      it "downloads all other files in the gist as well", ->
        atom.config.set 'sync-settings.extraFiles', ['test.tmp', 'test2.tmp']
        run (cb) ->
          SyncSettings.upload cb
        , ->
          run (cb) =>
            SyncSettings.download cb
          , ->
            for file in atom.config.get 'sync-settings.extraFiles'
              expect(fs.existsSync("#{atom.config.configDirPath}/#{file}")).toBe(true)
              fs.unlink "#{atom.config.configDirPath}/#{file}"