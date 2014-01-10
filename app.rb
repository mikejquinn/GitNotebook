require "bundler/setup"
require "sinatra/base"
require "sass"
require "pinion"
require "pinion/sinatra_helpers"
require "grit"
require "bourbon"

require "openid"
require "openid/extensions/ax"
require "openid/store/filesystem"

require "./environment"
require "./lib/realm"
require "./lib/repo"
require "./lib/db"
require "./models/user"

class GloGist < Sinatra::Base

  set :pinion, Pinion::Server.new("/assets")

  enable :sessions

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

  UNAUTHENTICATED_ROUTES=["/favicon", "/signin/complete"]
  OPENID_AX_EMAIL_EXTENSION="http://axschema.org/contact/email"

  before do
    next if UNAUTHENTICATED_ROUTES.any? { |route| request.path =~ (/^#{route}/) }

    unless logged_in?
      session[:initial_request_url] = request.url
      redirect openid_login_redirect_url(OPEN_ID_LOGIN_URL)
    end
  end

  get "/signin/complete" do
    openid_consumer = OpenID::Consumer.new(session, openid_store)
    openid_response = openid_consumer.complete(params, request.url)

    case openid_response.status
    when OpenID::Consumer::FAILURE then "Could not authenticate with #{openid_response.display_identifier}"
    when OpenID::Consumer::SETUP_NEEDED then "Authentication failed - Setup Needed"
    when OpenID::Consumer::CANCEL then "Login cancelled."
    when OpenID::Consumer::SUCCESS
      ax_resp = OpenID::AX::FetchResponse.from_success_response(openid_response)
      email = ax_resp[OPENID_AX_EMAIL_EXTENSION][0]

      unless user = User[email: email]
        user = User.create(email: email)
      end

      session[:user_id] = user.id
      redirect session[:initial_request_url] || "/"
    end
  end

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

  def current_user
    @current_user ||= User[id: session[:user_id]]
  end

  def logged_in?
    !!current_user
  end

  def openid_store
    session_dir = File.join(File.dirname(__FILE__), "tmp", "openid")
    FileUtils.mkdir_p(session_dir)
    @openid_store ||= OpenID::Store::Filesystem.new(session_dir)
  end

  def openid_login_redirect_url(openid_endpoint_url)
    consumer = OpenID::Consumer.new(session, openid_store)

    begin
      service = OpenID::OpenIDServiceEndpoint.from_op_endpoint_url(openid_endpoint_url)
      oidreq = consumer.begin_without_discovery(service, false)
    rescue OpenID::OpenIDError => e
      $stderr.puts "Discovery failed for #{openid_endpoint_url}: #{e}"
    else
      ax_request = OpenID::AX::FetchRequest.new
      # Information we require from the OpenID provider.
      required_fields = [OPENID_AX_EMAIL_EXTENSION]
      required_fields.each { |field| ax_request.add(OpenID::AX::AttrInfo.new(field, nil, true)) }
      oidreq.add_extension(ax_request)

      host = "#{request.scheme}://#{request.host_with_port}"
      return_to = "#{host}/signin/complete"
      oidreq.redirect_url(host, return_to)
    end
  end
end
