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
require "lib/script_environment"

class GitNotebook < Sinatra::Base

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
    also_reload "lib/*.rb"
    also_reload "models/*.rb"
  end

  helpers Pinion::SinatraHelpers

  UNAUTHENTICATED_ROUTES=["/favicon", "/signin/complete"]
  OPENID_AX_EMAIL_EXTENSION="http://axschema.org/contact/email"

  include Gravatar::SinatraHelpers

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

      puts "email: #{User[email]}"

      user = User[email: email]
      if user.nil?
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
    redirect url(projects_path)
  end

  get "/projects" do
    erb :"projects/index", locals: { projects: current_user.projects }
  end

  post "/projects" do
    if @project = Project.create_for_user(current_user, params[:name])
      redirect url(project_path(@project))
    else
      status 500
      "There was an error creating the project."
    end
  end

  # TODO: Should be an API route
  post %r{/projects/([A-Za-z0-9]*)} do |project_id|
    if project = Project[string_id: project_id]
      data = JSON.parse(request.body.read)
      @repo = Repo.new(project)
      index = @repo.index
      data["files"].each do |file|
        index.add(file["name"], file["text"])
      end
      data["deleted_paths"].each do |path|
        index.delete(path)
      end
      index.commit("message", [@repo.head.commit], nil, nil, "master")
      "OK"
    else
      status 404
    end
  end

  get %r{/projects/([A-Za-z0-9]*)/direct/([a-f0-9]*)/(.*)} do |project_id, commit_id, blob_name|
    if project = Project[string_id: project_id]
      @repo = Repo.new(project)
      blob = @repo.find_blob_for_committish(commit_id, blob_name)
      content_type :text
      blob.data
    else
      status 404
      "This project was not found"
    end
  end

  get %r{/projects/([A-Za-z0-9]*)/changes/(.*)} do |project_id, commit_id|
    if @project = Project[string_id: project_id]
      @repo = Repo.new(project)
      commit = @repo.committish(commit_id)
      diffs = commit.diffs
      erb :"projects/commit_changes", locals: { diffs: diffs, commit: commit }
    else
      status 404
      "This project was not found"
    end
  end

  get %r{/projects/([A-Za-z0-9]*)/versions} do |project_id|
    if @project = Project[string_id: project_id]
      @repo = Repo.new(@project)
      commits = @repo.grit.commits("master", 15)
      erb :"projects/versions", locals: { commits: commits }
    else
      status 404
      "This project was not found"
    end
  end

  get %r{/projects/([A-Za-z0-9]*)/edit/new_file} do |project_id|
    if project = Project[string_id: project_id]
      @repo = Repo.new(project)
      erb :"projects/edit_new_blob", layout: false, locals: { name: @repo.generate_file_name }
    else
      status 404
    end
  end

  get %r{/projects/([A-Za-z0-9]*)/edit} do |project_id|
    if @project = Project[string_id: project_id]
      @repo = Repo.new(@project)
      blobs = @repo.blobs_for_committish("master")
      erb :"projects/edit", locals: { blobs: blobs }
    else
      status 404
      "This project was not found"
    end
  end

  get %r{/projects/([A-Za-z0-9]*)/([a-f0-9]*)} do |project_id, commit_id|
    if @project = Project[string_id: project_id]
      @repo = Repo.new(@project)
      @commit = @repo.committish(commit_id)
      blobs = @repo.blobs_for_committish(commit_id)
      erb :"projects/show", locals: { blobs: blobs }
    else
      status 404
      "This project was not found"
    end
  end

  get %r{/projects/([A-Za-z0-9]*)} do |string_id|
    if @project = Project[string_id: string_id]
      @repo = Repo.new(@project)
      @commit = @repo.committish("master")
      blobs = @repo.blobs_for_committish("master")
      erb :"projects/show", locals: { blobs: blobs }
    else
      status 404
      "This project was not found"
    end
  end

  helpers do
    def development?
      ENV['RACK_ENV'].eql?("development")
    end

    def project
      @project
    end

    def repo
      @repo
    end

    def commit
      @commit ||= repo.committish("master")
    end

    def projects_path
      "/projects"
    end

    def project_path(project)
      "/projects/#{project.string_id}"
    end

    def edit_project_path(project)
      "/projects/#{project.string_id}/edit"
    end

    def project_new_file_path(project)
      "#{edit_project_path(project)}/new_file"
    end

    def project_commit_path(project, commit)
      "#{project_path(project)}/#{commit.id}"
    end

    def project_revisions_path(project)
      "#{project_path(project)}/versions"
    end

    def project_commit_changes_path(project, commit)
      "#{project_path(project)}/changes/#{commit.id}"
    end

    def project_raw_blob_path(project, blob)
      "#{project_path(project)}/direct/#{commit.id}/#{blob.name}"
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
