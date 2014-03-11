class Repo
  include Mongoid::Document

  # http://developer.github.com/v3/repos/#get
  field :id
  field :atom_url
  field :url
  field :name
  field :full_name
  field :owner_login
  field :stars_count
  field :forks_count
  field :created_at
  field :updated_at
  field :pushed_at
end
