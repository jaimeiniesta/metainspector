require 'bundler'
Bundler::GemHelper.install_tasks

require 'spec/rake/spectask'

Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = Dir.glob('spec/**/*_spec.rb')
  t.spec_opts << '--format specdoc'
  t.rcov = true
end
