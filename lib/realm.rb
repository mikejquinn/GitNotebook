require "grit"
class Realm

  attr_reader :id

  def self.load_all
    Dir["#{REPO_ROOT}/*"].map do |dir|
      dir.match("#{REPO_ROOT}/(.*)")
      Realm.new($1)
    end
  end

  def self.find_or_create(id)
    begin
      FileUtils.mkdir "#{REPO_ROOT}/#{id}"
    rescue Errno::EEXIST
    end
    Realm.new(id)
  end

  def initialize(id)
    @id = id
  end

  def path
    File.join(REPO_ROOT, @id)
  end

  def repos(reload = false)
    @repos = nil if reload
    @repos ||= Dir[File.join(path, "*.git")].map do |dir|
      repo_id = File.basename(dir).chomp(".git")
      Repo.new(self, repo_id)
    end
  end

  def get_repo(id)
    repos.find { |repo| repo.id.eql?(id) }
  end

  def create_repo(id)
    repo = Repo.create(self, id)
    @repos << repo if @repos
    repo
  end
end

