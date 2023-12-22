--[[----------------------------------------------------------------------------

This file is a part of Deduplicator Lightroom Classic CC plugin
Licenced under GPLv2 terms
GIT Repository with the code:
  https://github.com/teran/deduplicator

------------------------------------------------------------------------------]]

plugin_name = LOC "$$$/PluginInfo/Name=Deduplicator"
plugin_major = 1
plugin_minor = 0
plugin_revision = 3
plugin_build = _BUILD_NUMBER_
plugin_version = string.format('%s.%s.%s.%s', plugin_major, plugin_minor, plugin_revision, plugin_build)
plugin_id = 'me.teran.lightroom.deduplicator'
plugin_home_url = "https://github.com/teran/deduplicator"
latest_release_json_url = 'https://api.github.com/repos/teran/deduplicator/releases/latest'
log_target = 'logfile'

return {
  LrSdkVersion = 6.0,
  LrToolkitIdentifier = plugin_id,
  LrPluginName = plugin_name,
  LrPluginInfoUrl = plugin_home_url,
  LrLibraryMenuItems = {
    {
      title = 'Find duplicates',
      file = 'FindDuplicates.lua',
      enabledWhen = 'photosAvailable',
    },
    {
      title = 'Score images',
      file = 'ScoreImages.lua',
      enabledWhen = 'photosAvailable',
    },
    {
      title = 'Find blurry',
      file = 'FindBlurry.lua',
      enabledWhen = 'photosAvailable',
    },
    {
      title = 'Compare on pregenerated imgsum database',
      file = 'ImportImgsumDatabase.lua',
    },
  },
  LrHelpMenuItems = {
    title = 'Check for updates',
    file = 'GithubCheckUpdates.lua',
  },
  VERSION = { major=plugin_major, minor=plugin_minor, revision=plugin_revision, build=plugin_build, },
}
