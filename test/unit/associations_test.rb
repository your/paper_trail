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
        @ch_1 = @chapter.versions.last.reify(:has_many => true)
      end

      should "reify the record when reify is called" do
        assert_equal "ch_1", @ch_1.name
      end
    end

    context "after the first has_many through relationship is created" do
      setup do
        Timecop.travel 1.second.since
        @chapter.update_attributes :name => "ch_2"
        Timecop.travel 1.second.since
        @chapter.sections.create :name => "section 1"
        Timecop.travel 1.second.since
        @chapter.sections.first.update_attributes :name => "section 2"
        Timecop.travel 1.second.since
        @chapter.update_attributes :name => "ch_3"
        Timecop.travel 1.second.since
        @chapter.sections.first.update_attributes :name => "section 3"
      end

      context "when reify is called" do
        setup do
          @chapter_1 = @chapter.versions.last.reify(:has_many => true)
        end

        should "show the value of the base record as it was before" do
          assert_equal "ch_2", @chapter_1.name
        end

        should "show the value of the associated record as it was before the base record was updated" do
          assert_equal ['section 2'], @chapter_1.sections.map(&:name)
        end

        context "to the version before the relationship was created" do
          setup { @chapter_2 = @chapter.versions.second.reify(:has_many => true) }

          should "not return any associated records" do
            assert_equal 0, @chapter_2.sections.size
          end
        end

        context "to the version before the associated record has been destroyed" do
          setup do
            @chapter.update_attributes :name => 'ch_3'
            Timecop.travel 1.second.since
            @chapter.sections.destroy_all
            Timecop.travel 1.second.since
            @chapter_3 = @chapter.versions.last.reify(:has_many => true)
          end

          should "return the associated record" do
            assert_equal ['section 2'], @chapter_3.sections.map(&:name)
          end
        end

        context "to the version after the associated record has been destroyed" do
          setup do
            @chapter.sections.destroy_all
            Timecop.travel 1.second.since
            @chapter.update_attributes :name => 'ch_4'
            Timecop.travel 1.second.since
            @chapter_4 = @chapter.versions.last.reify(:has_many => true)
          end

          should "return the associated record" do
            assert_equal 0, @chapter_4.sections.size
          end
        end
      end

      context "after the nested has_many through relationship is created" do
        setup do
          @section = @chapter.sections.first
          @paragraph = @section.paragraphs.create :name => 'para1'
        end

        context "reify the associations" do
          setup do
            Timecop.travel 1.second.since
            @initial_section_name = @section.name
            @initial_paragraph_name = @paragraph.name
            @chapter.update_attributes :name => 'ch_5'
            Timecop.travel 1.second.since
            @paragraph.update_attributes :name => 'para3'
            Timecop.travel 1.second.since
            @chapter_4 = @chapter.versions.last.reify(:has_many => true)
          end

          should "to the version before the change was made" do
            assert_equal [@initial_section_name], @chapter_4.sections.map(&:name)
            assert_equal [@initial_paragraph_name], @chapter_4.sections.first.paragraphs.map(&:name)
          end
        end

        context "and the first has_many through relationship is destroyed" do
          setup do
            @section.destroy
            Timecop.travel 1.second.since
            @chapter.update_attributes(:name => 'chapter 6')
            Timecop.travel 1.second.since
            @chapter_before = @chapter.versions.last.reify(:has_many => true)
          end

          should "reify should not return any associated models" do
            assert_equal 0, @chapter_before.sections.size
            assert_equal 0, @chapter_before.paragraphs.size
          end
        end

        context "reified to the version before the nested has_many through relationship is destroyed" do
          setup do
            Timecop.travel 1.second.since
            @initial_paragraph_name = @section.paragraphs.first.name
            @chapter.update_attributes(:name => 'chapter 6')
            Timecop.travel 1.second.since
            @paragraph.destroy
            @chapter_before = @chapter.versions.last.reify(:has_many => true)
          end

          should "restore the associated has_many relationship" do
            assert_equal [@initial_paragraph_name], @chapter_before.sections.first.paragraphs.map(&:name)
          end
        end

        context "reified to the version after the nested has_many through relationship is destroyed" do
          setup do
            @paragraph.destroy
            Timecop.travel 1.second.since
            @chapter.update_attributes(:name => 'chapter 6')
            @chapter_before = @chapter.versions.last.reify(:has_many => true)
          end

          should "restore the associated has_many relationship" do
            assert_equal [], @chapter_before.sections.first.paragraphs
          end
        end
      end
    end
  end
end
