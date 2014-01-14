class Project < Sequel::Model
  many_to_many :users, join_table: :users_projects
  many_to_one :creator, key: :creator_id, class: :User

  def before_create
    super

    # Create an alphuneric string ID to be used to find the project on the filesystem
    # and identify it in a URL
    self.string_id = StringUtils.generate_alphanumeric(10)
  end

  def after_create
    Repo.create_for_project(self)
  end

  # Creates a new project along with the backing git repo and adds it to the user's
  # project collection
  def self.create_for_user(user, name = "New notebook")
    DB.transaction do
      project = Project.new(name: name)
      project.creator = user
      if project.save
        user.add_project(project)
        begin
          # Add a single file to get it started
          repo = Repo.create_for_project(project)
          index = Grit::Index.new(repo.grit)
          index.add("textfile1", "")
          index.commit("Created Notebook")
        rescue
          Logging.logger.error("Error creating repo: #{$!}")
          Repo.delete_for_project(project)
          raise
        end

        project
      else
        # TODO: display these to the user if there is anything they can do about it
        raise "Validation error"
      end
    end
  end
end
