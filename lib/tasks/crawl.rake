require 'open-uri'
require 'nokogiri'

desc "Repo test"
task :repo => :environment do
  RepoWorker.new.perform
end
