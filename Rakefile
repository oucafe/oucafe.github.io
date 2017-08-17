require 'html-proofer'
require 'jekyll'

task :default => [:test]

task :test => [:build, :html_proofer]

task :build do
  config = Jekyll.configuration({
    'source' => './',
    'destination' => './_site'
  })
  site = Jekyll::Site.new(config)
  Jekyll::Commands::Build.build site, config
end

task :html_proofer do
  file_ignore = %w{./_site/SwiftQuickRef/index.html ./_site/SwiftBeginnersGuide/index.html ./_site/the-scientific-method-for-startups.html}
  HTMLProofer.check_directory("./_site", {disable_external: true, check_favicon: true, file_ignore: file_ignore, parallel: { in_progresses: 3 }, typhoeus: { verbose: false }}).run
end

desc "Preview drafts"
task :drafts_preview do
  system "jekyll serve --drafts --lsi"
end

desc "Preview"
task :preview do
  system "jekyll serve --lsi"
end
