if ENV["MODEL_ADAPTER"] == "mongo_mapper"
  require "spec_helper"

  class MongoMapperCategory
    include MongoMapper::Document

    many :mongo_mapper_projects
  end

  class MongoMapperProject
    include MongoMapper::Document

    key :numbers, Array

    belongs_to :mongo_mapper_category
  end

  MongoMapper.database = 'cancan_mongo_mapper_spec'

  describe CanCan::ModelAdapters::MongoMapperAdapter do
    context "MongoMapper defined" do
      before(:each) do
        @ability = Object.new
        @ability.extend(CanCan::Ability)
      end

      after(:each) do
        MongoMapper.database.collections.select{|c| c.name !~ /system/ }.map {|c| c.drop }
      end

      it "should be for only Mongoid classes" do
        CanCan::ModelAdapters::MongoMapperAdapter.should_not be_for_class(Object)
        CanCan::ModelAdapters::MongoMapperAdapter.should be_for_class(MongoMapperProject)
        CanCan::ModelAdapters::AbstractAdapter.adapter_class(MongoMapperProject).should == CanCan::ModelAdapters::MongoMapperAdapter
      end

      it "should find record" do
        project = MongoMapperProject.create
        CanCan::ModelAdapters::MongoMapperAdapter.find(MongoMapperProject, project.id).should == project
      end

      it "should compare properties on mongoid documents with the conditions hash" do
        model = MongoMapperProject.new
        @ability.can :read, MongoMapperProject, :id => model.id
        @ability.should be_able_to(:read, model)
      end

      it "should be able to read hashes when field is array" do
        one_to_three = MongoMapperProject.create(:numbers => ['one', 'two', 'three'])
        two_to_five  = MongoMapperProject.create(:numbers => ['two', 'three', 'four', 'five'])

        @ability.can :foo, MongoMapperProject, :numbers => 'one'
        @ability.should be_able_to(:foo, one_to_three)
        @ability.should_not be_able_to(:foo, two_to_five)
      end

      it "should return [] when no ability is defined so no records are found" do
        MongoMapperProject.create(:title => 'Sir')
        MongoMapperProject.create(:title => 'Lord')
        MongoMapperProject.create(:title => 'Dude')

        MongoMapperProject.accessible_by(@ability, :read).entries.should == []
      end

      it "should return the correct records based on the defined ability" do
        @ability.can :read, MongoMapperProject, :title => "Sir"
        sir   = MongoMapperProject.create(:title => 'Sir')
        lord  = MongoMapperProject.create(:title => 'Lord')
        dude  = MongoMapperProject.create(:title => 'Dude')

        MongoMapperProject.accessible_by(@ability, :read).entries.should == [sir]
      end

      it "should be able to mix empty conditions and hashes" do
        @ability.can :read, MongoMapperProject
        @ability.can :read, MongoMapperProject, :title => 'Sir'
        sir  = MongoMapperProject.create(:title => 'Sir')
        lord = MongoMapperProject.create(:title => 'Lord')

        MongoMapperProject.accessible_by(@ability, :read).count.should == 2
      end

      it "should return everything when the defined ability is manage all" do
        @ability.can :manage, :all
        sir   = MongoMapperProject.create(:title => 'Sir')
        lord  = MongoMapperProject.create(:title => 'Lord')
        dude  = MongoMapperProject.create(:title => 'Dude')

        MongoMapperProject.accessible_by(@ability, :read).entries.should == [sir, lord, dude]
      end

      it "should allow a scope for conditions" do
        @ability.can :read, MongoMapperProject, MongoMapperProject.where(:title => 'Sir')
        sir   = MongoMapperProject.create(:title => 'Sir')
        lord  = MongoMapperProject.create(:title => 'Lord')
        dude  = MongoMapperProject.create(:title => 'Dude')

        MongoMapperProject.accessible_by(@ability, :read).entries.should == [sir]
      end

      describe "Mongoid::Criteria where clause Symbol extensions using MongoDB expressions" do
        it "should handle :field.in" do
          obj = MongoMapperProject.create(:title => 'Sir')
          @ability.can :read, MongoMapperProject, :title.in => ["Sir", "Madam"]
          @ability.can?(:read, obj).should == true
          MongoMapperProject.accessible_by(@ability, :read).entries.should == [obj]

          obj2 = MongoMapperProject.create(:title => 'Lord')
          @ability.can?(:read, obj2).should == false
        end

        describe "activates only when there are Criteria in the hash" do
          it "Calls where on the model class when there are criteria" do
            obj = MongoMapperProject.create(:title => 'Bird')
            @conditions = {:title.nin => ["Fork", "Spoon"]}

            @ability.can :read, MongoMapperProject, @conditions
            @ability.should be_able_to(:read, obj)
          end
          it "Calls the base version if there are no mongoid criteria" do
            obj = MongoMapperProject.new(:title => 'Bird')
            @conditions = {:id => obj.id}
            @ability.can :read, MongoMapperProject, @conditions
            @ability.should be_able_to(:read, obj)
          end
        end

        it "should handle :field.nin" do
          obj = MongoMapperProject.create(:title => 'Sir')
          @ability.can :read, MongoMapperProject, :title.nin => ["Lord", "Madam"]
          @ability.can?(:read, obj).should == true
          MongoMapperProject.accessible_by(@ability, :read).entries.should == [obj]

          obj2 = MongoMapperProject.create(:title => 'Lord')
          @ability.can?(:read, obj2).should == false
        end

        it "should handle :field.size" do
          obj = MongoMapperProject.create(:titles => ['Palatin', 'Margrave'])
          @ability.can :read, MongoMapperProject, :titles => { :$size => 2 }
          @ability.can?(:read, obj).should == true
          MongoMapperProject.accessible_by(@ability, :read).entries.should == [obj]

          obj2 = MongoMapperProject.create(:titles => ['Palatin', 'Margrave', 'Marquis'])
          @ability.can?(:read, obj2).should == false
        end

        it "should handle :field.exists" do
          obj = MongoMapperProject.create(:titles => ['Palatin', 'Margrave'])
          @ability.can :read, MongoMapperProject, :titles.exists => true
          @ability.can?(:read, obj).should == true
          MongoMapperProject.accessible_by(@ability, :read).entries.should == [obj]

          obj2 = MongoMapperProject.create
          @ability.can?(:read, obj2).should == false
        end

        it "should handle :field.gt" do
          obj = MongoMapperProject.create(:age => 50)
          @ability.can :read, MongoMapperProject, :age.gt => 45
          @ability.can?(:read, obj).should == true
          MongoMapperProject.accessible_by(@ability, :read).entries.should == [obj]

          obj2 = MongoMapperProject.create(:age => 40)
          @ability.can?(:read, obj2).should == false
        end

        it "should handle instance not saved to database" do
          obj = MongoMapperProject.new(:title => 'Sir')
          @ability.can :read, MongoMapperProject, :title => ["Sir", "Madam"]
          @ability.can?(:read, obj).should == true

          # accessible_by only returns saved records
          MongoMapperProject.accessible_by(@ability, :read).entries.should == []

          obj2 = MongoMapperProject.new(:title => 'Lord')
          @ability.can?(:read, obj2).should == false
        end
      end

      it "should call where with matching ability conditions" do
        obj = MongoMapperProject.create(:foo => {:bar => 1})
        @ability.can :read, MongoMapperProject, :foo => {:bar => 1}
        MongoMapperProject.accessible_by(@ability, :read).entries.first.should == obj
      end
      
      it "should exclude from the result if set to cannot" do
        obj = MongoMapperProject.create(:bar => 1)
        obj2 = MongoMapperProject.create(:bar => 2)
        @ability.can :read, MongoMapperProject
        @ability.cannot :read, MongoMapperProject, :bar => 2
        MongoMapperProject.accessible_by(@ability, :read).entries.should == [obj]
      end

      it "should combine the rules" do
        obj = MongoMapperProject.create(:bar => 1)
        obj2 = MongoMapperProject.create(:bar => 2)
        obj3 = MongoMapperProject.create(:bar => 3)
        @ability.can :read, MongoMapperProject, :bar => 1
        @ability.can :read, MongoMapperProject, :bar => 2
        MongoMapperProject.accessible_by(@ability, :read).entries.should =~ [obj, obj2]
      end
      
      it "should not allow to fetch records when ability with just block present" do
        @ability.can :read, MongoMapperProject do
          false
        end
        lambda {
          MongoMapperProject.accessible_by(@ability)
        }.should raise_error(CanCan::Error)
      end
    end
  end
end
