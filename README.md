Support Slogger by contributing to my [GitTip fund](https://www.gittip.com/ttscoff/).


## Upgrade Note ##

*If you are upgrading from a version prior to 2.0.12, please remove the RSSLogger section from `slogger_config` and regenerate it by running slogger again. A new section will be added in addition to RSSLogger called Bloglogger. RSSLogger now logs all entries for the timespan as a single digest entry, whereas Bloglogger loads each item found as an individual "post."*

## Description ##

Slogger indexes various public social services and creates Day One (<http://dayoneapp.com/>) journal entries or plain text Markdown files for them. It allows you to keep a personal journal that collects your online social life automatically, all in one place.

## Features ##

- Slogger 2.x uses a plugin architecture to allow easy extension
    - Default plugins:
        -  Github
            -  new plugin, supercedes Gist logger. 
            -  Logs push, watch and gist activity
        -  Flickr
            - images uploaded in the last 24 hours, each as an individual post
            - Can handle multiple accounts
        -  Last.fm 
            - Scrobbled songs for the current day
            - *updated to grab more songs*
        -  Blog entries
            -  designed to pull in your blog posts with leading image and excerpt (optionally markdownified). 
            -  Handles multiple feeds
        -  RSS Feeds
            -  logs any feed entries for the given timespan as a digest entry
            -  handles multiple feeds
        -  Twitter
            -  Tweets and Favorites for the day as digest entries
            -  handles multiple Twitter accounts
        -  Instapaper
            -  Unread and/or individual folders
        -  Foursquare 
            -  Checkins for the day
        -  Pinboard 
            -  Daily digest with descriptions
            -  optionally include bookmark tags in entry
        -  Pocket
            -  Digest list of links---read and unread---posted to Pocket
        -  Goodreads 
            -  books marked read for the day, one entry each with book cover image, ratings and your review. 
            -  Inserted at the date marked finished.
        -  App.net
            -  App.net posts for the current day    
        -  OmniFocus complete tasks for the day
    - There are additional plugins in the default "plugins_disabled" folder. They can be enabled by copying them to your "plugins" folder.
        - These are typically disabled by default because they require advanced setup or have limited use for most users. Read the headers in each plugin file for additional details.
        - Some of the additional plugins available:
            - GetGlue
            - Google Analytics (advanced setup)
            - Gist
            - SoundCloud
            - Strava
            -  untappd (requires [untappd](https://github.com/cmar/untappd) gem)
                - beer checkins for the day
            - Wunderlist new and optionally completed/overdue tasks (see notes for required gems/versions)
- Slogger can be called with a single argument that is a path to a local image or text file, and an entry will be created containing its contents.
    - You can use this with a folder action or launchd task to add files from a folder connected to something like <http://IFTTT.com>. Any images added to the watched folder will be turned into journal entries.
        -  Note that Slogger does not delete the original file, so your script needs to move files out of the folder manually to avoid double-processing.
- **NEW:** #tags in posts are saved as native tags. Default tags specified in the config are saved, as well as any hashtags present in the post. Github #XX issue references are ignored.

## Install ##

1. Download and unzip (or clone using git) the Slogger project. It can be stored in your home directory, a scripts folder or anywhere else on your drive.
2. Make sure you have the Xcode command line tools installed. (See Troubleshooting section below.)
3. From the command line, change to the Slogger folder and run the following commands:
        
        sudo gem install bundler
        bundle install 
4. Default plugins are stored in `/plugins/`, additional plugins are usually found in `/plugins_disabled/`. Plugins are enabled and disabled by adding/removing them from the `/plugins/` folder. Move any additional plugins you want to use into `/plugins/` and disable any other plugins by moving them from `/plugins/` to `plugins_disabled`. (Plugins that are found in `plugins` but not configured will not break anything, but you'll see warnings when run.)
5. From within the Slogger folder, run `./slogger --update-config` to create the initial configuration file. If this doesn't work, you may need to make the file executable: `chmod a+x slogger` from within the Slogger folder. Note that any time you add new plugins or update existing ones, you'll want to run `./slogger --update-config` to ensure that your available options are up to date.
6. Edit the file `slogger_config` that shows up in your Slogger folder
    - The required options will be 'storage:', 'image_filename_is_title:', 'date_format:' and 'time_format:'
    - storage: should be one of
        -  'icloud'
        -  a path to a Dropbox-synced Journal (e.g. '/Users/username/Dropbox/Apps/Day One/Journal.dayone')
        -  a path to a folder for storing markdown files and related images (if the path doesn't end in "Journal.dayone", markdown storage is triggered automatically)
    - image_filename_is_title: should be set to true or false. If true, it will use the base filename (without extension) as the title of images imported individually.
    - date_format and time_format should be set to your preferred style (strftime)

7. Edit additional configuration options for any plugins defined. The config file is formatted as YAML, and your options need to conform to that syntax. For the most part, you can just maintain the formatting (quotes, dashes, brackets, etc.) of the default settings when updating.
    - **Note:** Some plugins have options that will be filled in automatically. For example, the Twitter plugin requires you to log in on the command line and enter a PIN, after which it completes the authorization and saves your token to the configuration. If you install a plugin which requires oAuth, be sure to run Slogger from the command line with "./slogger -o plugin_name" once to complete the login procedure and save your credentials.
8. Next time you run `./slogger`, it will execute the enabled and configured plugins and generate your journal entries. 

## Usage ##

1. From within the Slogger folder, run `./slogger` to run the data
   capture for the plugins you have in you `/plugins/` directory. 
2. Check the output to see if there are any errors occurring. Plugin configuration errors can be ignored, or you can remove offending plugins from the `/plugins/` folder (if you don't need them).
3. If you wish to automate slogger: 
    - use [Lingon](http://www.peterborgapps.com/lingon/), [LaunchControl](http://www.soma-zone.com/LaunchControl/), or other `launchd` scheduling app, **or**...
    - run `./install.rb` to automatically install a launchd task that will run at 11:50pm every night. It's the same as Lingon would create, but all free and stuff.
        - To uninstall the launchd task, run the command `rm ~/Library/LaunchAgents/com.brettterpstra.slogger.plist` and then log out and back in.

## Command line options ##

    $ ./slogger -h
    Usage: slogger [-dq] [-r X] [/path/to/image.jpg]
        --update-config                  Create or update a slogger_config file. No plugins will be run.
        -c, --config FILE                Specify alternate configuration file
        -d, --develop                    Develop mode
        -h, --help                       Display this screen
        -o, --onlyrun NAME[,NAME2...]    Only run plugins matching items in comma-delimited string (partial names ok)
        -q, --quiet                      Run quietly (no notifications/messages)
        -r, --retries COUNT              Maximum number of retries per plugin (int)
        -s, --since-last                 Set the timespan to the last run date
        -t, --timespan DAYS              Days of history to collect
        -u, --undo COUNT                 Undo the last COUNT runs
        -v, --version                    Display the version number

> **Note:** You can use the `-s` option to only log since the last run date, handy if you want to run Slogger more or less than once per day or are testing plugins. 
>
> You can also use `-o` to run only a certain plugin in the standard plugin directory: just provide it with enough of the name to be unique, e.g. `slogger -o gist`.
>
> The `-u X` option will undo the last X runs. This works by checking the timestamp of the run and deleting any entries created after that timestamp. **It should not be used if you have manually created entries since the last Slogger run.** It also does not remove the run timestamps from the list, so running `./slogger -u 4` will remove the entries created by the last four runs, and then running `./slogger -u 5` will undo one more run in history.

## Updating Slogger ##

Slogger is currently actively maintained, meaning new fixes and features are regularly available. To update your Slogger installation, download the zip file for the latest version (the link on this page is always current) into a new folder. Copy the new files over existing files to update them. If you've enabled plugins that are disabled by default, you'll need to copy them from the new folder's "plugins_disabled" folder to your current "plugins" folder.

As long as you don't move or delete your `slogger_config` file, all of your settings will be preserved after the update.

## Plugin development ##

*More documentation coming*. See `plugin_template.rb` to get started.

If you want to edit an existing plugin to change parameters or output, move the original to `plugins_disabled` and make a copy with a new name in `plugins`. It will make it easier to update in the future without losing your changes.

When developing plugins you can create a directory called 'plugins_develop' in the same folder as 'plugins' and work on new plugins in there. When you run slogger, use `./slogger -d` to only run plugins in the develop folder while testing.

`@log` is a global logger object. use `@log.info("Message")` (or `warn`/`error`/`fatal`) to generate log messages using the default formatter.

`@config` is the global configuration object. Your plugin settings will be stored under `@config[PluginClassName]`. If you return the config object at the end of your do_log function, any modifications will be stored (e.g. for saving oAuth tokens).

`$options` contains options parsed from the command line. Use `$options[:optionname]` to read the setting.

- `:develop` whether Slogger was run in develop mode
- `:timespan` the timespan passed from the command line as number of days (int)
- `:quiet` suppresses log messages. This affects the log formatter and shouldn't generally be needed. Just create log messages using `@log` and if :quiet is true, they'll be suppressed.
- `:retries` is the number of retries to attempt on any given operation. Create loops in network calls and parsing routines to allow for retry on failure, and use `$options[:retries]` to determine how many times to iterate.

`@timespan` is available to all plugins and contains a date object based on the timespan setting. This defaults to 24 hours prior to the run.

`@date_format`, `@time_format` and `@datetime_format` (this is just the conjunction of the first two) are available to all plugins and should be used wherever you output a date or time to DayOne files, e.g. `Time.now.strftime(@date_format)`.

## Troubleshooting

### System Requirements

Slogger depends on Apple’s system Ruby version to run. You can check the Ruby version by typing `ruby -v` in your terminal, it should return something like `ruby 2.0.0p247 (2013-06-27 revision 41674) [universal.x86_64-darwin13]`.

As of the release of Mavericks Apple are providing Ruby version 2.0. Slogger is transitioning to full 2.0 support so meanwhile your mileage may vary.

If you are using RVM or RBENV to manage your Ruby installation, you can set an alternative Ruby version as the default.

For RVM check here: [https://rvm.io/rubies/default](https://rvm.io/rubies/default)

For RBENV check here: [https://github.com/sstephenson/rbenv#choosing-the-ruby-version](https://github.com/sstephenson/rbenv#choosing-the-ruby-version)

### Xcode Command Line Tools

In order for Slogger to run you must have an up-to-date version of Xcode's Command Line Tools installed.

Download Xcode from the OSX App Store. When it has downloaded launch it, open "Preferences", and under "Downloads" click on the arrow to the right of "Command Line Tools".

![](https://f.cloud.github.com/assets/222514/1398971/ee9b6a00-3cad-11e3-8583-c0c1ce804e3a.png)

Alternatively you can download the command line tools from Apple here: [https://developer.apple.com/downloads/index.action](https://developer.apple.com/downloads/index.action)

#### Known Issue with Xcode 5.1

Apple updated the clang compiler to version 5.1 with the latest Xcode update, which breaks building gems with native extensions. They fail with this error: `clang: error: unknown argument: '-multiply_definedsuppress' [-Wunused-command-line-argument-hard-error-in-future]`
You can check your version of clang with `clang -v` on the terminal. 

While that [bug is being worked on](https://bugs.ruby-lang.org/issues/9624), here is a temporary workaound:

First we need to install bundler.

```bash
sudo env ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future gem install bundler
```

And after that, use bundler to install other gems:

```bash
sudo env ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future bundle install
```

### Plugins

If Slogger is running, but returning an error message, it may be an issue with a plugin configuration.

It may help to move all plugins to the Disabled Plugins directory, and then add them back into the Plugins directory one by one, running `./slogger` each time to ensure it is not returning any errors. That way, you can identify if there is an issue with a particular Plugin.

Common issues with Plugins:

1. Feeds entered incorrectly. Multiple RSS feeds should be entered like
`feeds: [http://feed1.com/feed1.rss, http://feed2.com/feed2.rss, http://feed3.com/feed3.rss]`

2. Attempting to fetch an invalid feed. Feeds can be validated here: [http://validator.w3.org/feed/](http://validator.w3.org/feed/)

### Sync / Dropbox

It's not uncommon to have some sync issues using iCloud. The developers of the Day One app explicitly favour using Dropbox to sync your journal between your Mac and iPhone or iPad. So maybe use Dropbox.

If you are using Dropbox, a common location for your Day One Journal, which will need to be entered in the Slogger Config file under "Storage" is `/Users/YOURUSERNAME/Dropbox/Apps/Day One/Journal.dayone`. Please note that if you have moved your Dropbox, to your Desktop for instance, that would change the path required to `/Users/YOURUSERNAME/Desktop/Dropbox/Apps/Day One/Journal.dayone`

### Date and Time Formats

By default Slogger sets the Date format to ISO 8601 (Y/m/d) `"%F"` and the Time format to H:M (24-hour clock) `"%R"`. These settings can be changed to anything from the `strftime` specification, viewable here: [http://linux.die.net/man/3/strftime](http://linux.die.net/man/3/strftime).

The European Date format dd/mm/yy is not supported. The closest option is probably to set date to `"%x"` which is "The preferred date representation for the current locale without the time." 

## License

     __  _
    / _\| | ___   __ _  __ _  ___ _ __
    \ \ | |/ _ \ / _` |/ _` |/ _ \ '__|
    _\ \| | (_) | (_| | (_| |  __/ |
    \__/|_|\___/ \__, |\__, |\___|_|
                 |___/ |___/
         Copyright 2013, Brett Terpstra
               http://brettterpstra.com
                   --------------------

Slogger by Brett Terpstra is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License][license].

[license]: http://creativecommons.org/licenses/by-nc-sa/3.0/deed.en_US
