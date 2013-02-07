require "bundler/setup"
require "sinatra/base"
require "sass"
require "pinion"
require "pinion/sinatra_helpers"
require "grit"
require "bourbon"

require "./environment"
require "./lib/realm"

class GloGist < Sinatra::Base

  set :pinion, Pinion::Server.new("/assets")

  configure do
    pinion.convert :scss => :css
    pinion.convert :coffee => :js
    pinion.watch "public/javascripts"
    pinion.watch "public/scss"
    pinion.watch "#{Gem.loaded_specs["bourbon"].full_gem_path}/app/assets/stylesheets"
  end

  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
    also_reload "./lib/*.rb"
  end

  helpers Pinion::SinatraHelpers

  get "/" do
    erb :index, locals: { realms: Realm.load_all }
  end

  get "/:realm" do |realm|
    erb :realms, locals: { realm: Realm.new(realm) }
  end

  get "/:realm_name/:repo_name" do |realm_name, repo_name|
    realm = Realm.new(realm_name)
    repo = realm.get_repo(repo_name)
    head = repo.get_head("master")
    blobs = head.commit.tree.blobs
    erb :repo, locals: {
      realm: realm,
      repo: repo,
      repo_name: repo_name,
      branch: "master",
      blobs: blobs,
      new_file_path: url("/#{realm_name}/#{repo_name}/new_file")
    }
  end

  get "/:realm_name/:repo_name/new_file" do |realm_name, repo_name|
    realm = Realm.new(realm_name)
    repo = realm.get_repo(repo_name)
    head = repo.get_head("master")
    blobs = head.commit.tree.blobs
    erb :new_blob, locals: {
      realm: realm,
      repo: repo,
      repo_name: repo_name,
      branch: "master",
      save_url: url("/#{realm_name}/#{repo_name}/create_file")
    }
  end

  post "/:realm_name/:repo_name/create_file" do |realm_name, repo_name|
    realm = Realm.new(realm_name)
    repo = realm.get_repo(repo_name)
    head = repo.get_head("master")
    index = Grit::Index.new(repo)
    index.current_tree = head.commit.tree
    index.add(params["name"], params["text"])
    index.commit("New file.", [head.commit], nil, nil, "master")
    redirect url("/#{realm_name}/#{repo_name}")
  end

  get "/:realm/:repo_name/:branch/:blob/edit" do |realm_name, repo_name, branch, blob_name|
    realm = Realm.new(realm_name)
    repo = realm.get_repo(repo_name)
    head = repo.get_head(branch)
    blob = head.commit.tree.blobs.select { |b| b.name == blob_name }.first
    save_url = url("/#{realm_name}/#{repo_name}/#{branch}/#{blob_name}")
    erb :edit_blob, locals: { blob: blob, save_url: save_url, realm: realm, repo_name: repo_name }
  end

  get "/:realm_name/:repo_name/:blob/direct" do |realm_name, repo_name, blob_id|
    realm = Realm.new(realm_name)
    repo = realm.get_repo(repo_name)
    blob = repo.blob(blob_id)
    content_type :text
    blob.data
  end

  post "/:realm_name/:repo_name/:branch/:blob" do |realm_name, repo_name, branch_name, blob_name|
    realm = Realm.new(realm_name)
    repo = realm.get_repo(repo_name)
    head = repo.get_head(branch_name)
    index = Grit::Index.new(repo)
    index.current_tree = head.commit.tree
    index.add(blob_name, params["text"])
    index.commit("File updated.", [head.commit], nil, nil, branch_name)
    redirect url("/#{realm_name}/#{repo_name}")
  end

  post "/:realm_name/create_repo" do |realm_name|
    realm = Realm.new(realm_name)
    repo_name = params["name"]
    repo = realm.create_repo(repo_name)
    index = Grit::Index.new(repo)
    index.add("main", "Hello World")
    index.commit("Initial Commit")
    redirect url("/#{realm_name}/#{repo_name}")
  end

  helpers do
    def realm_path(realm)
      url("/#{realm.name}")
    end

    def repo_name(realm_name, repo)
      repo.path.match("\\A#{REPO_ROOT}/#{realm_name}/(.*)\.git\\Z")
      $1
    end

    def direct_path(realm, repo_name, file_name)
    end
  end

end

