# What's this?

A rails repo created to help demonstrate an issue with [qlty cli](http://github.com/qltysh/qlty) where both `rubocop` and `standardrb` plugins are unable to format/fix _rails related_ offenses despite being auto-correctable.

# Details

[standard](https://github.com/standardrb/standard) is a linter/formatter built on [RuboCop](https://github.com/rubocop/rubocop). Standard's CLI is invoked by calling `standardrb` and `qlty` named [it's plugin](https://github.com/qltysh/qlty/tree/main/qlty-plugins/plugins/linters/standardrb) to match that.

The qlty `standardrb` plugin works great most of the time but if you add the [standard-rails](https://github.com/standardrb/standard-rails) `extra_package`, any/all rubocop cops which have a `NOTE: Required Rails version:` of any kind like [this one](https://docs.rubocop.org/rubocop-rails/cops_rails.html#railsenumsyntax) or [this one](https://docs.rubocop.org/rubocop-rails/cops_rails.html#railsenvlocal), will fail to be formatted by the qlty standardrb plugin. The qlty `standardrb` plugin "linter" will be able to check/complain about it, but the "formatter" is unable to fix it.

This occurs because the rubocop source code expects to find [Gemfile.lock](https://github.com/rubocop/rubocop/blob/master/lib/rubocop/config.rb#L289) and [.bundle/config](https://github.com/rubocop/rubocop/blob/master/lib/rubocop/lockfile.rb#L78) files in a directory above where the cop is run from in order to format/fix offenses that have a specific "target_rails_version", _but_ qlty CLI executes the formatting inside of a folder at `/tmp/qlty` which prevents rubocop from formatting/fixing those offenses.

# How to replicate
Clone this repo
```bash
git clone git@github.com:milesstanfield/qlty-test.git
cd qlty-test
```

try to format this file with `standardrb` plugin
```bash
qlty fmt app/models/foo.rb --filter=standardrb
```

Notice the `check` command finds a standard-rails issue that the `fmt` command didnt fix
```bash
qlty check app/models/foo.rb --no-formatters --filter=standardrb
# app/models/foo.rb:3:3
# 3:3  medium  Use `Rails.env.local?` instead.  standardrb:Rails/EnvLocal
```

But if you were to use the standardrb cli directly with the same commands the qlty plugin runs [here](https://github.com/qltysh/qlty/blob/main/qlty-plugins/plugins/linters/standardrb/plugin.toml#L26), you'll find that it does fix it
```bash
# you'll need to locate the exact path to the 1.41.1-${identifier} you have locally and
# then replace the code below with that to use the standardrb executable that qlty has
# installed under the hood
~/.qlty/cache/tools/standardrb/1.41.1-56e214bd429f/gems/standard-1.41.1/exe/standardrb app/models/foo.rb --fix
```

It's fixed
```bash
qlty check app/models/foo.rb --no-formatters --filter=standardrb
# ✔ No issues
git diff
# -    Rails.env.development? || Rails.env.test?
# +    Rails.env.local?
```

You can also perform this same test with qlty `rubocop` plugin and have the same results
```bash
# this wont format it
qlty fmt app/models/foo.rb --filter=rubocop

# check to verify
qlty check app/models/foo.rb --no-formatters --filter=rubocop
# app/models/foo.rb:3:3
# 3:3  medium  Use `Rails.env.local?` instead.  standardrb:Rails/EnvLocal

# this _does_ format it
~/.qlty/cache/tools/rubocop/1.70.0-8d8faa68e17b/gems/rubocop-1.70.0/exe/rubocop --autocorrect app/models/foo.rb

# and now check to verify
qlty check app/models/foo.rb --no-formatters --filter=rubocop
# ✔ No issues
```

# Temporary Solution

Adding the following to `.qlty/qlty.toml` solves the `standardrb` issue, but it's a temporary hack until the underlying issue is resolved by qlty (somehow)
```toml
[plugins.definitions.standardrb.drivers.format]
script = """
lockfile=$(echo \"${config_file}\" | sed \"s/.standard.yml/Gemfile.lock/\");
destination=${PWD%/*};
cp -rf $lockfile $destination;
mkdir -p ${destination}/.bundle
cp -rf ~/.bundle/config ${destination}/.bundle;
standardrb ${target} --fix
"""
```

And similarly, this will resolve the `rubocop` issue though I did have to change the `script` command from `rubocop --fix-layout ${target}` to be `rubocop --autocorrect ${target}`. Honestly i suspect it _should_ be `--autocorrect` but that's a different issue altogether imo.
```toml
[plugins.definitions.rubocop.drivers.format]
script = """
lockfile=$(echo \"${config_file}\" | sed \"s/.rubocop.yml/Gemfile.lock/\");
destination=${PWD%/*};
cp -rf $lockfile $destination;
mkdir -p ${destination}/.bundle
cp -rf ~/.bundle/config ${destination}/.bundle;
rubocop --autocorrect ${target}
"""
```
