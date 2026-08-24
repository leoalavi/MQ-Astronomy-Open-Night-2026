# Generates ios/Flutter/Secrets.xcconfig from the project-root .env.
#
# Why this exists: iOS reads its native Maps SDK key from Info.plist's
# `GMSApiKey`, which is substituted from the `MAPS_API_KEY` BUILD SETTING at
# compile time. Without this file that setting is empty, so an app launched from
# Xcode — or with a plain `flutter run`, i.e. no `--dart-define-from-file=.env` —
# has no key at all and the Directions screen reports "not configured yet".
#
# Both the generated file and .env are git-ignored, so no secret is committed.
# Invoked from the Podfile (pre_install) and runnable directly:
#   ruby tool/sync_ios_secrets.rb
module AonSecrets
  KEY = 'MAPS_API_KEY'.freeze

  def self.env_value(env_path, name)
    return nil unless File.exist?(env_path)
    # Explicit UTF-8: comments in .env may carry non-ASCII, and Ruby would
    # otherwise read them as US-ASCII and raise on the first accented byte.
    File.readlines(env_path, encoding: 'UTF-8').each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#') || !line.include?('=')
      k, v = line.split('=', 2)
      return v.strip if k.strip == name
    end
    nil
  end

  # Writes the xcconfig when .env supplies a key. Returns a short status string
  # (never the key itself — this runs in build logs).
  def self.sync(project_root)
    env_path = File.join(project_root, '.env')
    out_path = File.join(project_root, 'ios', 'Flutter', 'Secrets.xcconfig')
    value = env_value(env_path, KEY)

    if value.nil? || value.empty?
      # Nothing to write. An existing hand-managed file is left ALONE — a
      # missing .env must never wipe a key someone set up by hand.
      return File.exist?(out_path) ? 'kept existing Secrets.xcconfig' : 'no key in .env — iOS ships dark'
    end

    body = <<~CFG
      // GENERATED from .env by tool/sync_ios_secrets.rb — do not edit or commit.
      // Feeds Info.plist's GMSApiKey ($(MAPS_API_KEY)) so the native Google map
      // is keyed even when the app is launched without --dart-define-from-file.
      #{KEY}=#{value}
    CFG

    return 'Secrets.xcconfig already current' if File.exist?(out_path) && File.read(out_path) == body

    FileUtils.mkdir_p(File.dirname(out_path))
    File.write(out_path, body)
    'wrote ios/Flutter/Secrets.xcconfig from .env'
  end
end

if __FILE__ == $PROGRAM_NAME
  require 'fileutils'
  puts "[aon] #{AonSecrets.sync(File.expand_path('..', __dir__))}"
end
