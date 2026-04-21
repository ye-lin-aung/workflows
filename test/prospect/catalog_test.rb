require "test_helper"

class Workflows::Prospect::CatalogTest < ActiveSupport::TestCase
  FIXTURE = File.expand_path("../fixtures/prospect/sample_catalog.yml", __dir__)

  test "loads all entries from the file" do
    c = Workflows::Prospect::Catalog.load_file(FIXTURE)
    assert_equal 3, c.entries.size
    assert_kind_of Workflows::Prospect::CatalogEntry, c.entries.first
  end

  test "filter by persona prefix" do
    c = Workflows::Prospect::Catalog.load_file(FIXTURE)
    admin = c.filter(persona_prefix: "admin")
    assert_equal 2, admin.size
    ids = admin.map(&:id)
    assert_includes ids, "admin_create_school"
    assert_includes ids, "admin_transfer_student"
    refute_includes ids, "student_check_grades"
  end

  test "filter by id suffix" do
    c = Workflows::Prospect::Catalog.load_file(FIXTURE)
    hits = c.filter(id_suffix: "create_school")
    assert_equal 1, hits.size
    assert_equal "admin_create_school", hits.first.id
  end

  test "filter combines persona_prefix and id_suffix" do
    c = Workflows::Prospect::Catalog.load_file(FIXTURE)
    hits = c.filter(persona_prefix: "admin", id_suffix: "create_school")
    assert_equal 1, hits.size
  end

  test "missing file raises" do
    assert_raises(Errno::ENOENT) do
      Workflows::Prospect::Catalog.load_file("/no/such/path.yml")
    end
  end

  test "duplicate ids raise" do
    Tempfile.create(["dup", ".yml"]) do |f|
      f.write(<<~YML)
        questions:
          - { id: x, persona: a, question: "q" }
          - { id: x, persona: b, question: "q" }
      YML
      f.close
      assert_raises(Workflows::Prospect::Catalog::DuplicateId) do
        Workflows::Prospect::Catalog.load_file(f.path)
      end
    end
  end
end
