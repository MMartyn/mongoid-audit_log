module Mongoid
  module AuditLog
    class Entry
      include Mongoid::Document
      include Mongoid::Timestamps::Created

      field :action, :type => Symbol
      field :tracked_changes, :type => Hash, :default => {}
      field :modifier_id, :type => String
      field :model_attributes, :type => Hash

      belongs_to :audited, :polymorphic => true

      index({ :audited_id => 1, :audited_type => 1 })
      index({ :modifier_id => 1 })

      scope :creates, -> { where(:action => :create) }
      scope :updates, -> { where(:action => :update) }
      scope :destroys, -> { where(:action => :destroy) }
      scope :newest, -> { order_by(:created_at.desc) }

      Mongoid::AuditLog.actions.each do |action_name|
        define_method "#{action_name}?" do
          action == action_name
        end
      end

      def valid?(*)
        result = super
        self.modifier = Mongoid::AuditLog.current_modifier if result
        result
      end

      def modifier
        @modifier ||= if modifier_id.blank?
                        nil
                      else
                        klass = Mongoid::AuditLog.modifier_class_name.constantize
                        klass.find(modifier_id)
                      end
      end

      def modifier=(modifier)
        self.modifier_id = if modifier.present? && modifier.respond_to?(:id)
                             modifier.id
                           else
                             modifier
                           end

        @modifier = modifier
      end

      def respond_to?(sym, *args)
        key = sym.to_s
        (model_attributes.present? && model_attributes.has_key?(key)) || super
      end

      def method_missing(sym, *args, &block)
        key = sym.to_s

        if model_attributes.present? && model_attributes.has_key?(key)
          model_attributes[key]
        else
          super
        end
      end
    end
  end
end
