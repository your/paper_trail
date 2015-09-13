require 'test_helper'
require 'time_travel_helper'

class AssociationsTest < ActiveSupport::TestCase
  # These would have been done in test_helper.rb if using_mysql? is true
  unless using_mysql?
    self.use_transactional_fixtures = false
    setup { DatabaseCleaner.start }
  end

  teardown do
    Timecop.return
    # This would have been done in test_helper.rb if using_mysql? is true
    DatabaseCleaner.clean unless using_mysql?
  end

  context "nested has_many through relationships" do
    setup { @chapter = Chapter.create(:name => 'ch_1') }

    context "before any associations are created" do
      setup do
        @chapter.update_attributes(:name => "ch_2")
      end

      should "not reify any associations" do
        chapter_v1 = @chapter.versions[1].reify(:has_many => true)
        assert_equal "ch_1", chapter_v1.name
        assert_equal [], chapter_v1.sections
        assert_equal [], chapter_v1.paragraphs
      end
    end

    context "after the first has_many through relationship is created" do
      setup do
        assert_equal 1, @chapter.versions.size

        Timecop.travel 1.second.since
        @chapter.update_attributes :name => "ch_2"
        assert_equal 2, @chapter.versions.size

        Timecop.travel 1.second.since
        @chapter.sections.create :name => "section 1"
        Timecop.travel 1.second.since
        @chapter.sections.first.update_attributes :name => "section 2"
        Timecop.travel 1.second.since
        @chapter.update_attributes :name => "ch_3"
        assert_equal 3, @chapter.versions.size

        Timecop.travel 1.second.since
        @chapter.sections.first.update_attributes :name => "section 3"
      end

      context "version 1" do
        should "have no sections" do
          chapter_v1 = @chapter.versions[1].reify(:has_many => true)
          assert_equal [], chapter_v1.sections
        end
      end

      context "version 2" do
        should "have one section" do
          chapter_v2 = @chapter.versions[2].reify(:has_many => true)
          assert_equal 1, chapter_v2.sections.size

          # Shows the value of the section as it was before
          # the chapter was updated.
          assert_equal ['section 2'], chapter_v2.sections.map(&:name)

          # Shows the value of the chapter as it was before
          assert_equal "ch_2", chapter_v2.name
        end
      end

      context "version 2, before the section was destroyed" do
        setup do
          @chapter.update_attributes :name => 'ch_3'
          Timecop.travel 1.second.since
          @chapter.sections.destroy_all
          Timecop.travel 1.second.since
        end

        should "have the one section" do
          chapter_v2 = @chapter.versions[2].reify(:has_many => true)
          assert_equal ['section 2'], chapter_v2.sections.map(&:name)
        end
      end

      context "version 3, after the section was destroyed" do
        setup do
          @chapter.sections.destroy_all
          Timecop.travel 1.second.since
          @chapter.update_attributes :name => 'ch_4'
          Timecop.travel 1.second.since
        end

        should "have no sections" do
          chapter_v3 = @chapter.versions[3].reify(:has_many => true)
          assert_equal 0, chapter_v3.sections.size
        end
      end

      context "after creating a paragraph" do
        setup do
          assert_equal 3, @chapter.versions.size
          @section = @chapter.sections.first
          @paragraph = @section.paragraphs.create :name => 'para1'
        end

        context "new chapter version" do
          should "have one paragraph" do
            initial_section_name = @section.name
            initial_paragraph_name = @paragraph.name
            Timecop.travel 1.second.since
            @chapter.update_attributes :name => 'ch_5'
            assert_equal 4, @chapter.versions.size
            Timecop.travel 1.second.since
            @paragraph.update_attributes :name => 'para3'
            chapter_v3 = @chapter.versions[3].reify(:has_many => true)
            assert_equal [initial_section_name], chapter_v3.sections.map(&:name)
            paragraphs = chapter_v3.sections.first.paragraphs
            assert_equal 1, paragraphs.size
            assert_equal [initial_paragraph_name], paragraphs.map(&:name)
          end
        end

        context "destroy a section" do
          should "not have any sections or paragraphs" do
            @section.destroy
            Timecop.travel 1.second.since
            @chapter.update_attributes(:name => 'chapter 6')
            assert_equal 4, @chapter.versions.size
            chapter_v3 = @chapter.versions[3].reify(:has_many => true)
            assert_equal 0, chapter_v3.sections.size
            assert_equal 0, chapter_v3.paragraphs.size
          end
        end

        context "the version before a paragraph is destroyed" do
          should "have the one paragraph" do
            initial_paragraph_name = @section.paragraphs.first.name
            Timecop.travel 1.second.since
            @chapter.update_attributes(:name => 'chapter 6')
            Timecop.travel 1.second.since
            @paragraph.destroy
            chapter_v3 = @chapter.versions[3].reify(:has_many => true)
            paragraphs = chapter_v3.sections.first.paragraphs
            assert_equal 1, paragraphs.size
            assert_equal initial_paragraph_name, paragraphs.first.name
          end
        end

        context "the version after a paragraph is destroyed" do
          should "have no paragraphs" do
            @paragraph.destroy
            Timecop.travel 1.second.since
            @chapter.update_attributes(:name => 'chapter 6')
            chapter_v3 = @chapter.versions[3].reify(:has_many => true)
            assert_equal 0, chapter_v3.paragraphs.size
            assert_equal [], chapter_v3.sections.first.paragraphs
          end
        end
      end
    end
  end
end
