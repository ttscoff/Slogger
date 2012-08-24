# Slogger

Social logging script for Day One

## Description ##

Slogger indexes various public social services and creates Day One (<http://dayoneapp.com/>) journal entries for them. It allows you to keep a personal journal that collects your online social life automatically, all in one place.

## Features ##

- Slogger 2.x uses a plugin architecture to allow easy extension
    - Default plugins:
        -  Gist (gists created in the last 24 hours. Title and description only, logged as a single digest)
        -  Flickr (images uploaded in the last 24 hours, each as an individual post. Can handle multiple accounts)
        -  Last.fm (Scrobbled songs for the current day)
        -  RSS feeds (designed to pull in your blog posts with leading image and excerpt (optionally markdownified). Handles multiple feeds)
        -  Twitter (Tweets and Favorites for the day as digest entries, handles multiple Twitter accounts)
        -  Foursquare (Checkins for the day)
- Slogger can be called with a single argument that is a path to a local image, and an entry will be created for that image.
    - You can use this with a folder action or launchd task to add files from a folder connected to something like <http://IFTTT.com>. Any images added to the watched folder will be turned into journal entries.
        -  Note that Slogger does not delete the original image, so your script needs to move files out of the folder manually to avoid double-processing.

## Usage ##

1. From within the Slogger folder, run `./slogger` to create the initial configuration file.
2. Edit the file `slogger_config` that shows up
    - The only options will be 'storage:' and 'image_filename_is_title:'
    - storage: should be set to either 'icloud' or a path to a Dropbox-synced Journal
    - image_filename_is_title: should be set to true or false. If true, it will use the base filename (without extension) as the title of images imported individually.
3. Move plugins you want to use into `./plugins/`, and plugins you want to disable into `./plugins_disabled`.
4. Run `./slogger` again to update the configuration file with enabled plugin options.
5. Edit `slogger_config` and fill in the necessary parameters for listed configuration settings.
6. Next time you run `./slogger`, it will execute the plugins and generate your log entries. Run it manually to test, and then automate it using Lingon (launchd) or other scheduling app.
7. You can install a launchd task that will automatically run at 11:50pm every night by running `install.rb`. It's the same as Lingon would create, but all automatic and everything.
    - To uninstall, delete `~/Library/LaunchAgents/com.brettterpstra.slogger` and log out and back in.

## Plugin development ##

*More documentation coming*. See `plugin_template.rb` to get started.

If you want to edit an existing plugin to change parameters or output, move the original to `plugins_disabled` and make a copy with a new name in `plugins`. It will make it easier to update in the future without losing your changes.

## Todo ##

- Command line options for timespan, undo, configuration, etc.
- Better handling of varying RSS feeds
- MOAR PLUGINS
- Better documentation method and help for individual plugins
