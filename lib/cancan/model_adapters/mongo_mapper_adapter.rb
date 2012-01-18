module CanCan
  module ModelAdapters
    class MongoMapperAdapter < AbstractAdapter
      def self.for_class?(model_class)
        model_class <= MongoMapper::Document
      end

      def self.override_conditions_hash_matching?(subject, conditions)
        conditions.any? do |k,v|
          key_is_not_symbol = lambda { !k.kind_of?(Symbol) }
          subject_value_is_array = lambda do
            subject.respond_to?(k) && subject.send(k).is_a?(Array)
          end

          key_is_not_symbol.call || subject_value_is_array.call
        end
      end

      def self.matches_conditions_hash?(subject, conditions)
        if subject.new_record?
          conditions = if rule.conditions.is_a?(Hash)
                         records.where rule.conditions
                       else
                         records.where rule.conditions.criteria.source
                       end
          conditions.reject{|k, v| k =~ /^\$/}

          subject.attributes.merge(conditions) == subject.attributes
        else
          subject.class.where(conditions).include? subject
        end
      end

      def database_records
        if @rules.size == 0
          @model_class.where(:_id => {'$exists' => false, '$type' => 7}) # return no records
        elsif @rules.size == 1 && @rules[0].conditions.is_a?(Hash)
          @model_class.where(@rules[0].conditions)
        else
          # we only need to process can rules if
          # there are no rules with empty conditions
          rules = @rules.reject { |rule| rule.conditions.empty? }
          process_can_rules = @rules.count == rules.count
          conditions = rules.map do |rule|
            if process_can_rules && rule.base_behavior
              if rule.conditions.is_a?(Hash)
                condition = rule.conditions
              else
                condition = rule.conditions.criteria.source
              end
            elsif !rule.base_behavior
              condition = rule.conditions.inject({}) do |exclude_rules, (k, v)|
                exclude_rules[k] = {:$ne => v}
                exclude_rules
              end
            end
            condition
          end
          @model_class.where(:$or => conditions.reject(&:nil?))
        end
      end
    end
  end
end

# simplest way to add `accessible_by` to all MongoMapper Documents
module MongoMapper::Document::ClassMethods
  include CanCan::ModelAdditions::ClassMethods
end
