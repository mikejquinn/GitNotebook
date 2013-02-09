require "grit"
class Repo
  attr_reader :id
  attr_reader :realm

  def self.create(realm, id)
    path = "#{realm.path}/#{id}.git"
    grit = Grit::Repo.init_bare(path)
    new(realm, id)
  end

  def initialize(realm, id)
    @realm = realm
    @id = id
  end

  def grit
    @grit ||= Grit::Repo.new(path)
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

  def path
    File.join(realm.path, "#{@id}.git")
  end
end

