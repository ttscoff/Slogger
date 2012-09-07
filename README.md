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
        -  Instapaper (Unread and/or individual folders)
        -  Foursquare (Checkins for the day)
        -  Pinboard (Daily digest with descriptions and option for tags)
        -  Pocket (Digest list of links, read and unread, posted to Pocket)
        -  Goodreads books marked read for the day, one entry each with book cover image, ratings and your review. Inserted at the date marked finished.
- Slogger can be called with a single argument that is a path to a local image, and an entry will be created for that image.
    - You can use this with a folder action or launchd task to add files from a folder connected to something like <http://IFTTT.com>. Any images added to the watched folder will be turned into journal entries.
        -  Note that Slogger does not delete the original image, so your script needs to move files out of the folder manually to avoid double-processing.

## Configure ##

1. From within the Slogger folder, run `./slogger` to create the initial configuration file. If this doesn't work, you may need to make the file executable: `chmod a+x slogger` from within the Slogger folder.
2. Edit the file `slogger_config` that shows up
    - The only options will be 'storage:' and 'image_filename_is_title:'
    - storage: should be set to either 'icloud' or a path to a
Dropbox-synced Journal (e.g. '/Users/username/Dropbox/Apps/Day One/Journal.dayone')
    - image_filename_is_title: should be set to true or false. If true, it will use the base filename (without extension) as the title of images imported individually.
3. Move any additional plugins you want to use from `/plugins_disabled/` into `/plugins/`.
4. Run `./slogger` again to update the configuration file with enabled plugin options.
5. Edit `slogger_config` again and fill in the necessary parameters for listed configuration settings.
6. Next time you run `./slogger`, it will execute the plugins and generate your log entries. 

## Usage ##

1. From within the Slogger folder, run `./slogger` to run the data
   capture for the plugins you have in you `/plugins/` directory. 
2. You may run `./slogger` manually to test, or if you do not with to automate the process.
3. If you wish to automate slogger use Lingon (launchd) or other scheduling app.
4. You can install a launchd task that will automatically run at 11:50pm every night by running `install.rb`. It's the same as Lingon would create, but all automatic and everything.
    - To uninstall the launchd task, run the command `rm ~/Library/LaunchAgents/com.brettterpstra.slogger` and then log out and back in.

## Command line options ##

    $ ./slogger -h
    Usage: slogger [-dq] [-r X] [/path/to/image.jpg]
        -c, --config FILE                Specify alternate configuration file
        -d, --develop                    Develop mode
        -o, --onlyrun NAME[,NAME2...]    Only run plugins matching items in comma-delimited string (partial names ok)
        -t, --timespan DAYS              Days of history to collect
        -q, --quiet                      Run quietly (no notifications/messages)
        -r, --retries COUNT              Maximum number of retries per plugin (int)
        -s, --since-last                 Set the timespan to the last run date
        -v, --version                    Display the version number
        -h, --help                       Display this screen

> **Note:** You can use the `-s` option to only log since the last run date, handy if you want to run Slogger more than once per day or are testing plugins. 
>
> You can also use `-o` to run only a certain plugin in the standard plugin directory: just provide it with enough of the name to be unique, e.g. `slogger -o gist`.

## Plugin development ##

*More documentation coming*. See `plugin_template.rb` to get started.

If you want to edit an existing plugin to change parameters or output, move the original to `plugins_disabled` and make a copy with a new name in `plugins`. It will make it easier to update in the future without losing your changes.

When developing plugins you can create a directory called 'plugins_develop' in the same folder as 'plugins' and work on new plugins in there. When you run slogger, use `./slogger -d` to only run plugins in the develop folder while testing.

`@log` is a global logger object. use `@log.info("Message")` (or `warn`/`error`/`fatal`) to generate log messages using the default formatter.

`@config` is the global configuration object. Your plugin settings will be stored under `@config[PluginClassName]`.

`$options` contains options parsed from the command line. Use `$options[:optionname]` to read the setting.

- `:develop` whether Slogger was run in develop mode
- `:timespan` the timespan passed from the command line as number of days (int)
- `:quiet` suppresses log messages. This affects the log formatter and shouldn't generally be needed. Just create log messages using `@log` and if :quiet is true, they'll be suppressed.
- `:retries` is the number of retries to attempt on any given operation. Create loops in network calls and parsing routines to allow for retry on failure, and use `$options[:retries]` to determine how many times to iterate.

`@timespan` is available to all plugins and contains a date object based on the timespan setting. This defaults to 24 hours prior to the run.
