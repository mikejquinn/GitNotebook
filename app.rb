require "bundler/setup"
require "sinatra/base"
require "sass"
require "pinion"
require "pinion/sinatra_helpers"
require "grit"
require "bourbon"

require "./environment"
require "./lib/realm"
require "./lib/repo"

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

  get "/favicon.ico" do
    ""
  end

  get "/" do
    erb :index, locals: { realms: Realm.load_all }
  end

  post "/create_realm" do
    @realm = Realm.find_or_create(params["name"])
    redirect realm_path
  end

  get "/:realm_id" do |realm_id|
    @realm = Realm.new(realm_id)
    erb :realms
  end

  get "/:realm_id/:repo_id" do |realm_id, repo_id|
    @realm = Realm.new(realm_id)
    @repo = realm.get_repo(repo_id)
    @commit = @repo.committish("master")
    blobs = @repo.blobs_for_committish("master")
    erb :repo, locals: { blobs: blobs }
  end

  post "/:realm_name/create_repo" do |realm_name|
    @realm = Realm.new(realm_name)
    repo_name = params["name"]
    @repo = @realm.create_repo(repo_name)
    index = Grit::Index.new(@repo.grit)
    index.add("textfile1", "")
    index.commit("Created Notebook")
    redirect repo_path
  end

  post "/:realm_id/:repo_id" do |realm_id, repo_id|
    data = JSON.parse(request.body.read)
    @realm = Realm.new(realm_id)
    @repo = @realm.get_repo(repo_id)
    index = @repo.index
    data["files"].each do |file|
      index.add(file["name"], file["text"])
    end
    data["deleted_paths"].each do |path|
      index.delete(path)
    end
    index.commit("message", [@repo.head.commit], nil, nil, "master")
    "OK"
  end

  get "/:realm_id/:repo_id/edit" do |realm_id, repo_id|
    @realm = Realm.new(realm_id)
    @repo = @realm.get_repo(repo_id)
    blobs = @repo.blobs_for_committish("master")
    erb :repo_edit, locals: { blobs: blobs }
  end

  get "/:realm_id/:repo_id/versions" do |realm_id, repo_id|
    @realm = Realm.new(realm_id)
    @repo = @realm.get_repo(repo_id)
    commits = @repo.grit.commits("master", 15)
    erb :repo_versions, locals: { commits: commits }
  end

  get "/:realm_id/:repo_id/:commit" do |realm_id, repo_id, commit|
    @realm = Realm.new(realm_id)
    @repo = realm.get_repo(repo_id)
    @commit = @repo.committish(commit)
    blobs = @repo.blobs_for_committish(commit)
    erb :repo, locals: { blobs: blobs }
  end

  get "/:realm_id/:repo_id/edit/new_file" do |realm_id, repo_id|
    @realm = Realm.new(realm_id)
    @repo = @realm.get_repo(repo_id)
    erb :repo_edit_new_blob, layout: false, locals: { name: @repo.generate_file_name }
  end

  get "/:realm_id/:repo_id/changes/:commit_id" do |realm_id, repo_id, commit_id|
    @realm = Realm.new(realm_id)
    @repo = @realm.get_repo(repo_id)
    commit = @repo.committish(commit_id)
    diffs = commit.diffs
    erb :repo_changes, locals: { diffs: diffs, commit: commit }
  end

  get "/:realm_id/:repo_id/direct/:commit_id/:blob_name" do |realm_id, repo_id, commit_id, blob_name|
    @realm = Realm.new(realm_id)
    @repo = @realm.get_repo(repo_id)
    blob = @repo.find_blob_for_committish(commit_id, blob_name)
    content_type :text
    blob.data
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

  helpers do
    def realm
      @realm
    end

    def repo
      @repo
    end

    def commit
      @commit ||= repo.committish("master")
    end

    def raw_blob_path(blob)
      url("#{realm.id}/#{repo.id}/direct/#{commit.id}/#{blob.name}")
    end

    def realms_path
      url("/")
    end

    def new_realm_path
      url("/create_realm")
    end

    def repo_path
      url("#{realm.id}/#{repo.id}")
    end

    def edit_repo_path
      url("#{realm.id}/#{repo.id}/edit")
    end

    def new_file_path
      "#{edit_repo_path}/new_file"
    end

    def realm_path(realm = nil)
      realm = @realm if realm.nil?
      url("/#{realm.id}")
    end

    def repo_path(repo = nil)
      repo = @repo if repo.nil?
      url("/#{repo.realm.id}/#{repo.id}")
    end

    def commit_path(commit)
      "#{repo_path}/#{commit.id}"
    end

    def revisions_path(repo = nil)
      repo = @repo if repo.nil?
      url("/#{repo.realm.id}/#{repo.id}/versions")
    end

    def commit_changes_path(commit = nil)
      commit = @commit if commit.nil?
      url("/#{@realm.id}/#{@repo.id}/changes/#{commit.id}")
    end

    def new_repo_path(realm = nil)
      realm = @realm if realm.nil?
      "#{realm_path(realm)}/create_repo"
    end

    def repo_name(realm_name, repo)
      repo.path.match("\\A#{REPO_ROOT}/#{realm_name}/(.*)\.git\\Z")
      $1
    end

    def direct_path(realm, repo_name, file_name)
    end
  end

end

