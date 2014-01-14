require "grit"
class Repo
  # Splits the project's alphanumeric ID to distribute git repos into subfolders
  def self.path_for_project(project)
    string_id = project.string_id
    File.join(REPO_ROOT, string_id[0,2], "#{string_id[2, string_id.length]}.git")
  end

  def self.create_for_project(project)
    path = Repo.path_for_project(project)
    FileUtils.mkdir_p(path)
    grit = Grit::Repo.init_bare(path)
    new(project)
  end

  def self.delete_for_project(project)
  end

  attr_reader :project, :path, :grit

  def initialize(project)
    @project = project
    @path = Repo.path_for_project(@project)
    @grit = Grit::Repo.new(@path)
  end

  def index
    index = Grit::Index.new(grit)
    index.current_tree = head.commit.tree
    index
  end

  def head
    grit.get_head("master")
  end

  # Returns all blobs that are associated with a specific commit
  #
  #   @repo.blobs_for_committish("master")
  #   => [<Grit::Blob>, <Grit::Blob>]
  #
  # committish - a commit SHA, branch name, or tag name
  def blobs_for_committish(committish)
    commits = grit.batch(committish)
    unless commits.empty?
      commits.first.tree.blobs
    end
  end

  def find_blob_for_committish(committish, blob_name)
    if blobs = blobs_for_committish(committish)
      blobs.first { |blob| blob.name?(blob_name) }
    end
  end

  def committish(committish)
    grit.batch(committish).first
  end

  def generate_file_name
    blobs = blobs_for_committish("master")
    names = blobs.map(&:name)
    i = 1
    while names.include?("file#{i}.txt")
      i += 1
    end
    "file#{i}.txt"
  end
end
