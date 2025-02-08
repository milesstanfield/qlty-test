# What's this?

A rails repo created to help demonstrate/replicate an issue with [qlty cli](http://github.com/qltysh/qlty).

# Details

[standard](https://github.com/standardrb/standard) is a linter/formatter built on [RuboCop](https://github.com/rubocop/rubocop). Standard's CLI is invoked by calling `standardrb` and `qlty` named [it's plugin](https://github.com/qltysh/qlty/tree/main/qlty-plugins/plugins/linters/standardrb) to match that.

The plugin works great most of the time but if you add the [standard-rails](https://github.com/standardrb/standard-rails) `extra_package`, any/all rubocop cops which have a `NOTE: Required Rails version:` of any kind like [this one](https://docs.rubocop.org/rubocop-rails/cops_rails.html#railsenumsyntax) or [this one](https://docs.rubocop.org/rubocop-rails/cops_rails.html#railsenvlocal), will fail to be formatted by the qlty standardrb plugin. The qlty standardrb plugin "linter" will be able to check/complain about it, but the "formatter" is unable to fix it.

This occurs because the rubocop source code expects to find [Gemfile.lock](https://github.com/rubocop/rubocop/blob/master/lib/rubocop/config.rb#L289) and [.bundle/config](https://github.com/rubocop/rubocop/blob/master/lib/rubocop/lockfile.rb#L78) files in a directory above where the cop is run from in order to format/fix offenses that have a specific "target_rails_version", _but_ qlty CLI executes the formatting inside of a folder at `/tmp/qlty` which prevents rubocop from formatting/fixing those offenses.

# How to replicate
Clone the repo
```bash
git clone git@github.com:milesstanfield/qlty-test.git
cd qlty-test
```

See the qlty linter list an issue for this standard-rails complaint
```bash
qlty check app/models/foo.rb --no-formatters
# app/models/foo.rb:3:3
# 3:3  medium  Use `Rails.env.local?` instead.  standardrb:Rails/EnvLocal
```

And now try to format the same file
```bash
qlty fmt app/models/foo.rb
```

Notice it did not fix the issue (it _is_ an auto-correctable offense)
```bash
qlty check app/models/foo.rb --no-formatters
# app/models/foo.rb:3:3
# 3:3  medium  Use `Rails.env.local?` instead.  standardrb:Rails/EnvLocal
```

But if you were to use the standardrb cli directly, and the same commands the qlty plugin runs [here](https://github.com/qltysh/qlty/blob/main/qlty-plugins/plugins/linters/standardrb/plugin.toml#L26), you'll find that it does fix it
```bash
# you'll need to locate the exact path to the 1.41.1-${identifier} you have and
# then replace the code below with that to use the standardrb executable qlty has
# installed under the hood
~/.qlty/cache/tools/standardrb/1.41.1-56e214bd429f/gems/standard-1.41.1/exe/standardrb app/models/foo.rb --fix
```

It's fixed
```bash
qlty check app/models/foo.rb --no-formatters
# ✔ No issues
git diff
# -    Rails.env.development? || Rails.env.test?
# +    Rails.env.local?
```

# Temporary Solution

Adding the following to `.qlty/qlty.toml` solves the issue, but it's a temporary hack until the underlying issue is resolved by qlty (somehow)
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
