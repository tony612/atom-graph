class RepoWorker
  include Sidekiq::Worker

  def perform
    base_url = "https://atom.io"
    page_path = "/packages/list"
    page_url = base_url + page_path

    # FIXME: Maybe timeout
    home = Nokogiri::HTML(Typhoeus.get(page_url).body)
    page_total = home.css('.pagination a:not(.next_page)').last.content
    list_links = ("1"..page_total).map { |p| "#{page_url}?page=#{p}" }

    # Find the atom home url for each package
    links = list_links.inject([]) do |memo, page|
      current = Nokogiri::HTML(Typhoeus.get(page).body)
      memo.concat(current.css('.package-name a').map do |l|
        { :atom_url => URI.escape(base_url + l['href']) }
      end)
    end

    # Find all the responsing repo url(github)
    links = links.map do |link|
      begin
        l = link[:atom_url]
        pkg_page = Nokogiri::HTML(Typhoeus.get(l).body)
        link[:url] = pkg_page.css('.package-meta > a').
          map { |l| l['href'] }.
          # make sure it's a right github url
          select { |url| url =~ /^https?:\/\/github.com\/[\.\w-]+\/[\.\w-]+$/ }.first
        link
      rescue StandardError => e
        Rails.logger.fatal "ERROR in finding github link, #{e}"
        Rails.logger.debug "Package atom link: #{l}"
      end
    end
    insert_repos(links)
  end

  def insert_repos(links)
    links.each do |link|
      url = link[:url]
      if Repo.where({url: url}).count == 0
        owner, name = link[:url].split('/').last(2)
        repo = Octokit.repo(owner + '/' + name)

        attrs = [:id, :name, :full_name, :forks_count,
         :created_at, :updated_at, :pushed_at].inject({}) do |memo, key|
          memo[key] = repo[key]
          memo
        end
        attrs[:atom_url] = link[:atom_url]
        attrs[:url] = url
        attrs[:owner_login] = repo.owner.login
        attrs[:stars_count] = repo.stargazers_count
        Repo.create(attrs)
      end

    end
  end

  def self.start
    perform_async
  end
end
