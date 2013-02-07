require "grit"
class Realm

  attr_reader :name

  def self.load_all
    Dir["#{REPO_ROOT}/*"].map do |dir|
      dir.match("#{REPO_ROOT}/(.*)")
      Realm.new($1)
    end
  end

  def initialize(name)
    @name = name
  end

  def repos
    @repos ||= Dir["#{REPO_ROOT}/#{@name}/*.git"].map do |dir|
      Grit::Repo.new(dir)
    end
  end

  def get_repo(name)
    Grit::Repo.new("#{REPO_ROOT}/#{@name}/#{name}.git")
  end

  def create_repo(name)
    Grit::Repo.init_bare("#{REPO_ROOT}/#{@name}/#{name}.git")
  end
end

