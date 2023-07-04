require "strscan"

class PrometheusParser
  class Invalid < StandardError
    def initialize
      super("invalid input")
    end
  end

  KEY_RE = /[\w:]+/
  VALUE_RE = /-?\d+\.?\d*E?-?\d*|NaN|unknown/
  ATTR_KEY_RE = /[ \w-]+/
  ATTR_VALUE_RE = /\s*"([^"\\]*(\\.[^"\\]*)*)"\s*/ # /\s*"(\S*)"\s*/

  def self.parse(raw)
    s = StringScanner.new(raw)
    res = []
    until s.eos?
      if s.peek(1) == "#" || s.peek(1) == "\n" # Skip comment and empty lines
        s.scan(/.*\n/)
        next
      end
      key = s.scan KEY_RE
      raise Invalid unless key
      begin
        attrs = parse_attrs(s)
      rescue Invalid
        s.scan(/.*\n/)
        next
      end
      value = s.scan VALUE_RE
      # Workaround for faulty RabbitMQ metrics exporter
      # https://github.com/rabbitmq/rabbitmq-server/discussions/5143
      value = Float::NAN if %w[unknown NaN].include?(value)
      raise Invalid unless value
      value = value.to_f
      s.scan(/\n/)
      res.push({ key:, attrs:, value: })
    end
    res
  end

  def self.parse_attrs(s)
    attrs = {}
    if s.scan(/\s|{/) == "{"
      loop do
        if s.peek(1) == "}"
          s.scan(/}/)
          break
        end
        key = s.scan ATTR_KEY_RE
        raise Invalid unless key
        key = key.strip.to_sym
        s.scan(/=/)
        s.scan ATTR_VALUE_RE

        value = s[1] # grab first match of ATTR_VALUE_RE
        raise Invalid unless value
        attrs[key] = value
        break if s.scan(/,|}/) == "}"
      end
      s.scan(/\s/)
    end
    attrs
  end
end
