module Steep
  module Interface
    class Params
      attr_reader :required
      attr_reader :optional
      attr_reader :rest
      attr_reader :required_keywords
      attr_reader :optional_keywords
      attr_reader :rest_keywords

      def initialize(required:, optional:, rest:, required_keywords:, optional_keywords:, rest_keywords:)
        @required = required
        @optional = optional
        @rest = rest
        @required_keywords = required_keywords
        @optional_keywords = optional_keywords
        @rest_keywords = rest_keywords
      end

      def ==(other)
        other.is_a?(self.class) &&
          other.required == required &&
          other.optional == optional &&
          other.rest == rest &&
          other.required_keywords == required_keywords &&
          other.optional_keywords == optional_keywords &&
          other.rest_keywords == rest_keywords
      end

      def flat_unnamed_params
        required.map {|p| [:required, p] } + optional.map {|p| [:optional, p] }
      end

      def flat_keywords
        required_keywords.merge optional_keywords
      end

      def has_keywords?
        !required_keywords.empty? || !optional_keywords.empty? || rest_keywords
      end

      def each_missing_argument(args)
        required.size.times do |index|
          if index >= args.size
            yield index
          end
        end
      end

      def each_extra_argument(args)
        return if rest

        if has_keywords?
          args = args.take(args.count - 1) if args.count > 0
        end

        args.size.times do |index|
          if index >= required.count + optional.count
            yield index
          end
        end
      end

      def each_missing_keyword(args)
        return unless has_keywords?

        keywords, rest = extract_keywords(args)

        return unless rest.empty?

        required_keywords.each do |keyword, _|
          yield keyword unless keywords.key?(keyword)
        end
      end

      def each_extra_keyword(args)
        return unless has_keywords?
        return if rest_keywords

        keywords, rest = extract_keywords(args)

        return unless rest.empty?

        all_keywords = flat_keywords
        keywords.each do |keyword, _|
          yield keyword unless all_keywords.key?(keyword)
        end
      end

      def extract_keywords(args)
        last_arg = args.last

        keywords = {}
        rest = []

        if last_arg&.type == :hash
          last_arg.children.each do |element|
            case element.type
            when :pair
              if element.children[0].type == :sym
                name = element.children[0].children[0]
                keywords[name] = element.children[1]
              end
            when :kwsplat
              rest << element.children[0]
            end
          end
        end

        [keywords, rest]
      end

      def each_type()
        if block_given?
          flat_unnamed_params.each do |(_, type)|
            yield type
          end
          flat_keywords.each do |_, type|
            yield type
          end
          rest and yield rest
          rest_keywords and yield rest_keywords
        else
          enum_for :each_type
        end
      end

      def closed?
        required.all?(&:closed?) && optional.all?(&:closed?) && (!rest || rest.closed?) && required_keywords.values.all?(&:closed?) && optional_keywords.values.all?(&:closed?) && (!rest_keywords || rest_keywords.closed?)
      end

      def subst(s)
        self.class.new(
          required: required.map {|t| t.subst(s) },
          optional: optional.map {|t| t.subst(s) },
          rest: rest&.subst(s),
          required_keywords: required_keywords.transform_values {|t| t.subst(s) },
          optional_keywords: optional_keywords.transform_values {|t| t.subst(s) },
          rest_keywords: rest_keywords&.subst(s)
        )
      end

      def size
        required.size + optional.size + (rest ? 1 : 0) + required_keywords.size + optional_keywords.size + (rest_keywords ? 1 : 0)
      end
    end

    class Block
      attr_reader :params
      attr_reader :return_type

      def initialize(params:, return_type:)
        @params = params
        @return_type = return_type
      end

      def ==(other)
        other.is_a?(self.class) && other.params == params && other.return_type == return_type
      end

      def closed?
        params.closed? && return_type.closed?
      end

      def subst(s)
        self.class.new(
          params: params.subst(s),
          return_type: return_type.subst(s)
        )
      end
    end

    class MethodType
      attr_reader :type_params
      attr_reader :params
      attr_reader :block
      attr_reader :return_type
      attr_reader :location

      NONE = Object.new

      def initialize(type_params:, params:, block:, return_type:, location:)
        @type_params = type_params
        @params = params
        @block = block
        @return_type = return_type
        @location = location
      end

      def ==(other)
        other.is_a?(self.class) &&
          other.type_params == type_params &&
          other.params == params &&
          other.block == block &&
          other.return_type == return_type &&
          (!other.location || !location || other.location == location)
      end

      def subst(s)
        s_ = s.except(type_params)

        self.class.new(
          type_params: type_params,
          params: params.subst(s_),
          block: block&.subst(s_),
          return_type: return_type.subst(s_),
          location: location
        )
      end

      def each_type(&block)
        if block_given?
          params.each_type(&block)
          self.block&.tap do
            self.block.params.each_type(&block)
            yield(self.block.return_type)
          end
          yield(return_type)
        else
          enum_for :each_type
        end
      end

      def instantiate(s)
        self.class.new(
          type_params: [],
          params: params.subst(s),
          block: block&.subst(s),
          return_type: return_type.subst(s),
          location: location,
          )
      end
    end
  end
end
